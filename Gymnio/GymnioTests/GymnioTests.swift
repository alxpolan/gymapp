import Testing
@testable import Gymnio

struct PlaybookRulesTests {
    @Test func reviewPromptAfterSecondEntry() {
        #expect(AppStore.shouldRequestReview(entryCount: 2, distinctDays: 1, alreadyAsked: false))
    }

    @Test func reviewPromptStaysQuietOnFirstEntry() {
        #expect(!AppStore.shouldRequestReview(entryCount: 1, distinctDays: 1, alreadyAsked: false))
    }

    @Test func reviewPromptAskedOnlyOnce() {
        #expect(!AppStore.shouldRequestReview(entryCount: 60, distinctDays: 9, alreadyAsked: true))
    }

    @Test func entryLimitBlocksFreeUsers() {
        #expect(PremiumManager.isEntryLimitReached(entryCount: 30, limit: 30, isPro: false, suppressedRegion: false))
    }

    @Test func entryLimitPassesBelowLimit() {
        #expect(!PremiumManager.isEntryLimitReached(entryCount: 29, limit: 30, isPro: false, suppressedRegion: false))
    }

    @Test func entryLimitPassesProUsers() {
        #expect(!PremiumManager.isEntryLimitReached(entryCount: 99, limit: 30, isPro: true, suppressedRegion: false))
    }

    @Test func entryLimitPassesSuppressedRegions() {
        #expect(!PremiumManager.isEntryLimitReached(entryCount: 99, limit: 30, isPro: false, suppressedRegion: true))
    }
}
