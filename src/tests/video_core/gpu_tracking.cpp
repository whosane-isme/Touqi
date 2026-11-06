// SPDX-FileCopyrightText: Copyright 2026 Eden Emulator Project
// SPDX-License-Identifier: GPL-3.0-or-later

#include <algorithm>
#include <array>
#include <atomic>
#include <random>
#include <span>
#include <thread>
#include <utility>
#include <vector>

#include <catch2/catch_test_macros.hpp>

#include "video_core/buffer_cache/usage_tracker.h"
#include "video_core/buffer_cache/word_manager.h"
#include "video_core/nx2.h"

namespace {

constexpr u64 Page = 4096;
using Ranges = std::vector<std::pair<u64, size_t>>;

// Restore even when a REQUIRE aborts the test; touch only the reserved test window.
struct WrittenPagesWindow {
    static constexpr size_t FirstWord = 8192;
    static constexpr size_t Words = 8;
    static constexpr u64 Base = FirstWord * 64 * Page;
    static constexpr u64 Size = Words * 64 * Page;
    std::array<u64, Words> saved{};

    WrittenPagesWindow() {
        for (size_t i = 0; i < Words; ++i) {
            saved[i] = Tegra::g_nx2_gpu_written_pages[FirstWord + i].exchange(0);
        }
    }
    ~WrittenPagesWindow() {
        for (size_t i = 0; i < Words; ++i) {
            Tegra::g_nx2_gpu_written_pages[FirstWord + i].store(saved[i]);
        }
    }
};

void MarkExpected(std::array<u64, WrittenPagesWindow::Words>& expected, u64 offset, u64 size) {
    if (size == 0) {
        return;
    }
    for (u64 page = offset / Page; page <= (offset + size - 1) / Page; ++page) {
        expected[page / 64] |= u64{1} << (page % 64);
    }
}

void CheckWritten(const std::array<u64, WrittenPagesWindow::Words>& expected) {
    for (size_t i = 0; i < expected.size(); ++i) {
        REQUIRE(Tegra::g_nx2_gpu_written_pages[WrittenPagesWindow::FirstWord + i].load() ==
                expected[i]);
    }
}

class TrackingRecorder {
public:
    void UpdatePagesCachedCount(DAddr address, size_t size, s32 delta) {
        REQUIRE(delta == 1);
        ranges.emplace_back(address, size);
    }
    void UpdatePagesCachedBatch(std::span<const std::pair<DAddr, size_t>> batch, s32 delta) {
        REQUIRE(delta == 1);
        ranges.insert(ranges.end(), batch.begin(), batch.end());
    }
    Ranges ranges;
};

void AppendPage(Ranges& ranges, u64 address) {
    if (!ranges.empty() && ranges.back().first + ranges.back().second == address) {
        ranges.back().second += Page;
    } else {
        ranges.emplace_back(address, Page);
    }
}

} // namespace

TEST_CASE("GPU-written bitmap batches preserve page boundaries and repeated marks",
          "[video_core][gpu_tracking]") {
    WrittenPagesWindow window;
    std::array<u64, WrittenPagesWindow::Words> expected{};
    const auto mark = [&](u64 offset, u64 size) {
        Tegra::Nx2MarkGpuWritten(window.Base + offset, size);
        MarkExpected(expected, offset, size);
        CheckWritten(expected);
    };
    for (const auto [offset, size] : Ranges{{0, 0}, {0, 1}, {Page - 1, 2},
                                          {63 * Page + 1, Page}, {64 * Page, 64 * Page},
                                          {128 * Page - 1, 64 * Page + 2},
                                          {window.Size - 1, 1}}) {
        mark(offset, size);
        mark(offset, size);
    }
    std::mt19937_64 random{0xb17ba7c4};
    for (size_t i = 0; i < 400; ++i) {
        const u64 offset = random() % window.Size;
        mark(offset, random() % ((std::min<u64>)(window.Size - offset, 70 * Page) + 1));
    }
}

TEST_CASE("GPU-written bitmap retains overlapping concurrent updates",
          "[video_core][gpu_tracking]") {
    WrittenPagesWindow window;
    constexpr size_t workers = 4;
    std::array<Ranges, workers> writes;
    std::array<u64, WrittenPagesWindow::Words> expected{};
    std::mt19937_64 random{0xc0111de};
    for (auto& ranges : writes) {
        for (size_t i = 0; i < 256; ++i) {
            const u64 offset = random() % window.Size;
            const u64 size = 1 + random() % (std::min<u64>)(window.Size - offset, 3 * Page);
            ranges.emplace_back(offset, size);
            MarkExpected(expected, offset, size);
        }
    }
    std::atomic<bool> start{};
    std::vector<std::jthread> threads;
    for (size_t index = 0; index < workers; ++index) {
        threads.emplace_back([&, index] {
            while (!start.load(std::memory_order_acquire)) {
                std::this_thread::yield();
            }
            for (const auto [offset, size] : writes[index]) {
                Tegra::Nx2MarkGpuWritten(window.Base + offset, size);
            }
        });
    }
    start.store(true, std::memory_order_release);
    threads.clear();
    CheckWritten(expected);
}

TEST_CASE("Usage tracking matches byte overlap at block and page boundaries",
          "[video_core][gpu_tracking]") {
    constexpr u64 bytes = 8 * Page;
    VideoCommon::UsageTracker tracker{bytes};
    std::array<bool, bytes / 64> blocks{};
    const auto mark = [&](u64 offset, u64 size) {
        tracker.Track(offset, size);
        for (size_t block = 0; block < blocks.size(); ++block) {
            blocks[block] = blocks[block] ||
                            (size != 0 && block * 64 < offset + size && offset < (block + 1) * 64);
        }
        for (size_t block = 0; block < blocks.size(); ++block) {
            REQUIRE(((tracker.Pages()[block / 64] >> (block % 64)) & 1) == blocks[block]);
        }
        REQUIRE(tracker.Pages().back() == 0);
    };
    const auto query = [&](u64 offset, u64 size) {
        bool expected = false;
        for (size_t block = 0; block < blocks.size(); ++block) {
            expected |= blocks[block] && size != 0 && block * 64 < offset + size &&
                        offset < (block + 1) * 64;
        }
        REQUIRE(tracker.IsUsed(offset, size) == expected);
    };
    for (const auto [offset, size] : Ranges{{0, 0}, {63, 1}, {64, 1}, {127, 2},
                                          {Page - 1, 2}, {Page, 0}, {2 * Page, 3 * Page},
                                          {bytes - 1, 1}, {bytes, 0}}) {
        mark(offset, size);
        query(offset, size);
    }
    std::mt19937_64 random{0x64b10c};
    for (size_t step = 0; step < 1000; ++step) {
        if (step % 23 == 0) {
            tracker.Reset();
            tracker.Reset();
            blocks.fill(false);
            mark(2 * Page, 3 * Page); // Reuse the previous full-page run after Reset.
        }
        const u64 offset = random() % bytes;
        const u64 size = random() % ((std::min<u64>)(bytes - offset, 2 * Page) + 1);
        mark(offset, size);
        const u64 query_offset = random() % bytes;
        query(query_offset, random() % (bytes - query_offset + 1));
        query(offset, 0);
    }
}

TEST_CASE("Clean-word skips preserve modified ranges, tracking and bitmap state",
          "[video_core][gpu_tracking]") {
    using Type = VideoCommon::Type;
    using Manager = VideoCommon::WordManager<TrackingRecorder, 4, 4 * 64 * Page>;
    constexpr u64 base = 0x400000;
    std::mt19937_64 random{0xc1ea0};
    for (size_t trial = 0; trial < 600; ++trial) {
        TrackingRecorder recorder;
        Manager manager{base, recorder};
        for (auto& word : manager.heap) {
            word = random() % 3 == 0 ? random() : 0;
        }
        for (size_t word = 0; word < Manager::num_words; ++word) {
            manager.NoteCleanWord(word);
        }
        const auto initial = manager.heap;
        for (const auto type : {Type::CPU, Type::CachedCPU, Type::GPU, Type::Preflushable}) {
            for (const bool clear : {false, true}) {
                manager.heap = initial;
                for (size_t word = 0; word < Manager::num_words; ++word) {
                    manager.NoteCleanWord(word);
                }
                recorder.ranges.clear();
                auto expected = initial;
                Ranges expected_ranges;
                Ranges expected_tracking;
                const size_t first = random() % 256;
                const size_t count = 1 + random() % (256 - first);
                for (size_t page = first; page < first + count; ++page) {
                    const size_t word = page / 64;
                    const u64 bit = u64{1} << (page % 64);
                    auto& state = expected[size_t(type) * Manager::num_words + word];
                    auto& untracked = expected[size_t(Type::Untracked) * Manager::num_words + word];
                    auto& cached = expected[size_t(Type::CachedCPU) * Manager::num_words + word];
                    if (type == Type::GPU && (untracked & bit)) {
                        continue;
                    }
                    const bool modified = (state & bit) != 0;
                    if (modified) {
                        AppendPage(expected_ranges, base + page * Page);
                    }
                    if (clear) {
                        if (type == Type::CPU || type == Type::CachedCPU) {
                            if (untracked & bit) {
                                AppendPage(expected_tracking, base + page * Page);
                            }
                            untracked &= ~bit;
                        }
                        state &= ~bit;
                        if (type == Type::CPU && modified) {
                            cached &= ~bit;
                        }
                    }
                }
                Ranges actual;
                manager.ForEachModifiedRange(type, clear, base + first * Page, count * Page,
                                             [&](u64 address, u64 size) {
                                                 actual.emplace_back(address, size);
                                             });
                REQUIRE(actual == expected_ranges);
                REQUIRE(recorder.ranges == expected_tracking);
                REQUIRE(manager.heap == expected);
                REQUIRE(manager.CleanWordsHold());
            }
        }
    }
}
