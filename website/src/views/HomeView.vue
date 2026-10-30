<template>
  <div class="home">
    <Header></Header>
    <section class="hero">
      <!-- <div class="hero-image">
        <--  <img src="/hero-devices.png" alt="Paste app on multiple devices" />--
  </div>-->
      <div class="hero-content">
        <h1 class="hero-title" v-html="config.headline"></h1>
        <p class="hero-description" v-html="config.description"></p>
        <button @click="goToDownload()" class="cta-button-large">{{
          config.ctaButtonText }}</button>
      </div>
    </section>
    <section class="iphone-section">
      <div class="feature-cards-left" v-if="!mobile">
        <div class="feature-card card-float-1">
          <div class="card-connector connector-left"></div>
          <div class="feature-card-icon icon-green">
            <span>✓</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>Set logged</strong></div>
            <div class="feature-card-subtitle">Bench Press — 80 kg × 8 reps</div>
          </div>
        </div>
        <div class="feature-card card-float-2">
          <div class="card-connector connector-left"></div>
          <div class="feature-card-icon icon-yellow">
            <span>🏆</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>New personal best!</strong></div>
            <div class="feature-card-subtitle">Squat — 120 kg</div>
          </div>
        </div>
        <div class="feature-card card-float-3">
          <div class="card-connector connector-left"></div>
          <div class="feature-card-icon icon-blue">
            <span>📊</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title">Charts unlocked</div>
            <div class="feature-card-subtitle">3 entries reached — view your progress</div>
          </div>
        </div>
        <div class="feature-card card-float-4">
          <div class="card-connector connector-left"></div>
          <div class="feature-card-icon icon-coral">
            <span>🎉</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>25 workouts logged!</strong></div>
            <div class="feature-card-subtitle">Milestone reached — keep going</div>
          </div>
        </div>
        <div class="feature-card card-float-5">
          <div class="card-connector connector-left"></div>
          <div class="feature-card-icon icon-orange">
            <span>↗</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>Volume this week</strong></div>
            <div class="feature-card-subtitle">Total: 4,320 kg lifted</div>
          </div>
        </div>
      </div>
      <div class="iphone-container">
        <img height="650" src="/assets/iphone.png"
          alt="iPhone showing app interface"><!--:height="mobile ? '1000' : '650'"-->
      </div>
      <div class="feature-cards-right" v-if="!mobile">
        <div class="feature-card card-float-1">
          <div class="card-connector connector-right"></div>
          <div class="feature-card-icon icon-blue">
            <span>💪</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>Ready to level up!</strong></div>
            <div class="feature-card-subtitle">Deadlift — try 140 kg next session</div>
          </div>
        </div>
        <div class="feature-card card-float-2">
          <div class="card-connector connector-right"></div>
          <div class="feature-card-icon icon-gray-light">
            <span>🔒</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title">No account needed</div>
            <div class="feature-card-subtitle">Workouts stored on your device</div>
          </div>
        </div>
        <div class="feature-card card-float-3">
          <div class="card-connector connector-right"></div>
          <div class="feature-card-icon icon-avatar">
            <span>⚖️</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title text-coral"><strong>kg & lbs supported</strong></div>
            <div class="feature-card-subtitle">Switch units anytime in Settings</div>
          </div>
        </div>
        <div class="feature-card card-float-4">
          <div class="card-connector connector-right"></div>
          <div class="feature-card-icon icon-yellow-soft">
            <span>🌙</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title">Dark Mode</div>
            <div class="feature-card-subtitle">Light, Dark or follows system</div>
          </div>
        </div>
        <div class="feature-card card-float-5">
          <div class="card-connector connector-right"></div>
          <div class="feature-card-icon icon-green">
            <span>DE</span>
          </div>
          <div class="feature-card-content">
            <div class="feature-card-title"><strong>Deutsch & English</strong></div>
            <div class="feature-card-subtitle">Fully localized for both languages</div>
          </div>
        </div>
      </div>
    </section>
    <section class="dowload-section">
      <button class="download-btn" @click="downloadOnAppStore()"><img height="100" src="/assets/app_store.svg"
          alt="Apple App Store Badge"></button>
      <button class="download-btn" @click="downloadOnGooglePlay()"><img height="100" src="/assets/google_play.svg"
          alt="Google Play Store Badge"></button>
    </section>
    <section class="feature-showcase">
      <h2 class="showcase-title">{{ config.showcase_title }}</h2>
      <div class="showcase-carousel">
        <div class="showcase-card" v-for="feature in config.feature_list" :key="feature.title">
          <span class="showcase-tag">{{ feature.title }}</span>
          <h3 class="showcase-card-title" v-html="feature.description"></h3>
          <div class="showcase-image-container">
            <img src="/assets/iphone.png" :alt="'Feature ' + feature.title">
          </div>
        </div>
      </div>
      <div class="carousel-navigation">
        <button class="carousel-nav-btn"
          @click="scrollCarousel(-1)"><span>‹</span></button><!-- text-align text-center-->
        <button class="carousel-nav-btn"
          @click="scrollCarousel(1)"><span>›</span></button><!-- text-align text-center-->
      </div>
    </section>
    <section class="feature-detail-section">
      <div class="feature-detail-header">
        <h2 class="feature-detail-title" v-html="config.feature_detail.title"></h2>
        <p class="feature-detail-description">
          {{ config.feature_detail.description }}
        </p>
      </div>
      <div class="feature-detail-content">
        <div class="feature-detail-text">
          <h3 class="feature-highlight-title">{{ config.feature_highlight.title }}</h3>
          <p class="feature-highlight-description">
            {{ config.feature_highlight.description }}
          </p>
        </div>
        <div class="feature-detail-phones">
          <div class="phone-stack">
            <img :src="config.feature_highlight.image1" alt="App Feature 1" class="phone-back">
            <img :src="config.feature_highlight.image2" alt="App Feature 2" class="phone-front">
          </div>
        </div>
      </div>
    </section>
    <section class="reviews-section">
      <h2 class="reviews-title">{{ config.reviews.title }}</h2>
      <div class="reviews-grid">
        <div class="reviews-column" v-for="(columnReviews, colIndex) in groupedReviews" :key="colIndex">
          <template v-for="review in columnReviews" :key="review.name">
            <div v-if="review.type === 'tweet'" class="review-card review-tweet">
              <div class="review-header">
                <div class="review-avatar">
                  <span>{{ review.avatar }}</span>
                </div>
                <div class="review-author">
                  <span class="author-name">{{ review.name }}</span>
                  <span class="author-handle">{{ review.handle }}</span>
                </div>
              </div>
              <template v-if="Array.isArray(review.texts)">
                <p v-for="(text, idx) in review.texts" :key="idx" class="review-text">{{ text }}</p>
              </template>
              <p v-else class="review-text">{{ review.text }}</p>
            </div>
            <div v-else-if="review.type === 'testimonial'" class="review-card review-testimonial">
              <div class="review-header">
                <div class="review-avatar">
                  <span>{{ review.avatar }}</span>
                </div>
                <div class="review-author">
                  <span class="author-name">{{ review.name }}</span>
                  <span class="author-handle">{{ review.handle }}</span>
                </div>
                <span class="review-date">{{ review.date }}</span>
              </div>
              <p class="review-text">{{ review.text }}</p>
            </div>
            <div v-else-if="review.type === 'appstore'" class="review-card review-appstore">
              <div class="review-header">
                <span class="review-store-title">{{ review.title }}</span>
                <span class="review-date">{{ review.date }}</span>
              </div>
              <div class="review-stars">{{ '★'.repeat(review.stars) }}</div>
              <p class="review-text">{{ review.text }}</p>
            </div>
            <div v-else-if="review.type === 'social'" class="review-card review-social">
              <div class="review-header">
                <div class="review-avatar avatar-small">
                  <span>{{ review.avatar }}</span>
                </div>
                <div class="review-author">
                  <span class="author-name">{{ review.name }}</span>
                  <span class="author-handle">{{ review.handle }}</span>
                </div>
              </div>
              <div class="review-video-placeholder">
                <div class="video-overlay">
                  <span class="video-caption">{{ review.videoCaption }}</span>
                </div>
                <img src="/assets/iphone.png" alt="Video preview" class="video-preview-img">
              </div>
              <div class="review-social-footer">
                <div class="social-avatars">
                  <span class="mini-avatar">👤</span>
                  <span class="mini-avatar">👤</span>
                  <span class="mini-avatar">👤</span>
                </div>
                <span class="social-stat">{{ review.socialStat }}</span>
                <button v-if="review.viewMoreBtn" class="view-more-btn">View more +</button>
              </div>
            </div>
          </template>
        </div>
      </div>
    </section>
    <Footer></Footer>
  </div>
</template>

<script setup lang="ts">
import Header from '../components/Header.vue';
import Footer from '../components/Footer.vue';
import { inject, computed } from 'vue'

const config: any = inject('config')
const mobile = window.innerWidth <= 900;

const groupedReviews = computed(() => {
  const reviews = (config.reviews?.reviews as any[]) || []
  const cols: any[][] = [[], [], []]
  reviews.forEach((review: any, index: number) => {
    const col = cols[index % 3]
    if (col) {
      col.push(review)
    }
  })
  return cols
})

const downloadOnAppStore = () => {
  location.href = config.iosLink
}

const downloadOnGooglePlay = () => {
  location.href = config.androidLink
}

const scrollCarousel = (direction: number) => {
  const carousel = document.querySelector('.showcase-carousel')
  if (carousel) {
    const scrollAmount = 340 * direction
    carousel.scrollBy({ left: scrollAmount, behavior: 'smooth' })
  }
}

function getOS() {
  const ua = navigator.userAgent || navigator.vendor || (window as any).opera || '';

  if (/android/i.test(ua)) return "android";
  if (/iPad|iPhone|iPod/.test(ua) && !(window as any).MSStream) return "ios";

  return "unknown";
}

const os = getOS();
console.log("Detected OS:", os);

function goToDownload() {
  location.href = (os == 'android' ? config.androidLink : config.iosLink)
}
</script>

<style scoped>
.download-btn {
  background: none;
  border: none;
  cursor: pointer;
  margin: 0 10px;
  padding: 0;
}

.dowload-section {
  text-align: center;
  margin: 40px 0;
}

.iphone-section {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 80px 20px;
  position: relative;
  max-width: 1400px;
  margin: 0 auto;
  min-height: 700px;
  overflow: visible;
}

.feature-cards-left,
.feature-cards-right {
  display: flex;
  flex-direction: column;
  gap: 16px;
  position: absolute;
  z-index: 1;
  top: 50%;
  transform: translateY(-50%);
}

.feature-cards-left {
  right: calc(50% + 250px);
  align-items: flex-end;
}

.feature-cards-right {
  left: calc(50% + 250px);
  align-items: flex-start;
}

.feature-cards-left .card-float-1 {
  transform: translateX(90px);
  opacity: 0.4;
}

.feature-cards-left .card-float-2 {
  transform: translateX(40px);
  opacity: 1;
}

.feature-cards-left .card-float-3 {
  transform: translateX(70px);
  opacity: 0.5;
}

.feature-cards-left .card-float-4 {
  transform: translateX(20px);
  opacity: 0.9;
}

.feature-cards-left .card-float-5 {
  transform: translateX(60px);
  opacity: 0.6;
}

.feature-cards-right .card-float-1 {
  transform: translateX(-30px);
  opacity: 0.95;
}

.feature-cards-right .card-float-2 {
  transform: translateX(-80px);
  opacity: 0.45;
}

.feature-cards-right .card-float-3 {
  transform: translateX(-50px);
  opacity: 1;
}

.feature-cards-right .card-float-4 {
  transform: translateX(-100px);
  opacity: 0.35;
}

.feature-cards-right .card-float-5 {
  transform: translateX(-70px);
  opacity: 0.5;
}

.feature-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: rgb(255, 255, 255);
  border-radius: 16px;
  padding: 14px 18px;
  box-shadow:
    rgba(0, 0, 0, 0.04) 0px 0px 0px 1px,
    rgba(0, 0, 0, 0.02) 0px 1px 1px 0.5px,
    rgba(0, 0, 0, 0.02) 0px 3px 3px 1.5px,
    rgba(0, 0, 0, 0.02) 0px 6px 6px -3px,
    rgba(0, 0, 0, 0.02) 0px 12px 12px -6px,
    rgba(0, 0, 0, 0.02) 0px 24px 24px -12px;
  max-width: 300px;
  transition: transform 0.3s ease, box-shadow 0.3s ease, opacity 0.3s ease;
  position: relative;
}

.card-connector {
  position: absolute;
  top: 0;
  height: 100%;
  width: 420px;
  background: linear-gradient(to right, rgb(255, 255, 255) 0%, rgba(255, 255, 255, 0.6) 60%, rgba(255, 255, 255, 0) 100%);
  z-index: -1;
  pointer-events: none;
}

.connector-left {
  left: 100%;
  border-radius: 0 16px 16px 0;
}

.connector-right {
  right: 100%;
  background: linear-gradient(to left, rgb(255, 255, 255) 0%, rgba(255, 255, 255, 0.6) 60%, rgba(255, 255, 255, 0) 100%);
  border-radius: 16px 0 0 16px;
}

.feature-card:hover {
  transform: translateY(-2px) scale(1.02);
  box-shadow:
    rgba(0, 0, 0, 0.06) 0px 0px 0px 1px,
    rgba(0, 0, 0, 0.04) 0px 2px 2px 1px,
    rgba(0, 0, 0, 0.04) 0px 4px 4px 2px,
    rgba(0, 0, 0, 0.04) 0px 8px 8px -4px,
    rgba(0, 0, 0, 0.04) 0px 16px 16px -8px,
    rgba(0, 0, 0, 0.04) 0px 32px 32px -16px;
  z-index: 10;
  opacity: 1 !important;
}

.card-faded:hover {
  opacity: 1 !important;
}

.card-prominent:hover {
  opacity: 1 !important;
}

.feature-card-icon {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 18px;
  background: #f5f5f5;
}

.icon-blue {
  background: linear-gradient(135deg, #4A90D9, #357ABD);
  color: white;
}

.icon-coral {
  background: #FF6B6B;
  color: white;
}

.icon-green {
  background: #4CD964;
  color: white;
}

.icon-yellow {
  background: linear-gradient(135deg, #FFD54F, #FFC107);
  color: #333;
}

.icon-yellow-soft {
  background: #FFE082;
  color: #333;
}

.icon-brown {
  background: #8D6E63;
  color: white;
}

.icon-orange {
  background: linear-gradient(135deg, #FF7043, #F4511E);
  color: white;
}

.icon-gray-light {
  background: #F5F5F5;
  color: #9E9E9E;
}

.icon-avatar {
  background: #E8E8E8;
  border-radius: 50%;
}

.feature-card-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.feature-card-title {
  font-size: 14px;
  font-weight: 500;
  color: #1a1a1a;
  line-height: 1.3;
}

.feature-card-subtitle {
  font-size: 12px;
  color: #999;
  line-height: 1.4;
}

.text-faded {
  color: #BDBDBD;
}

.text-coral {
  color: #FF5252;
}

.text-coral-faded {
  color: #FF8A80;
}

.iphone-container {
  flex-shrink: 0;
  z-index: 5;
  position: relative;
}

.iphone-container img {
  display: block;
  filter: drop-shadow(0 25px 50px rgba(0, 0, 0, 0.15));
}

.home {
  min-height: 100vh;
  background: #fff;
}

.cta-button {
  background: #007AFF;
  color: white;
  border: none;
  padding: 8px 20px;
  border-radius: 20px;
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.cta-button:hover {
  background: #0051D5;
}

.hero {
  padding-top: 80px;
  text-align: center;
}

.hero-image {
  max-width: 1200px;
  margin: 0 auto;
  padding: 40px 24px;
}

.hero-image img {
  width: 100%;
  height: auto;
  display: block;
}

.hero-content {
  max-width: 900px;
  margin: 60px auto;
  padding: 0 24px;
}

@media (max-width: 900px) {
  .hero-content {
    padding: 14px;
    /*8*/
    margin: 40px auto;
  }
}

.hero-title {
  font-size: 64px;
  font-weight: 700;
  line-height: 1.1;
  color: #000;
  margin: 0 0 24px 0;
  letter-spacing: -0.02em;
}

/*@media (max-width: 900px) {
  .hero-title {
    font-size: 112px;
  }
}*/

.hero-description {
  font-size: 22px;
  line-height: 1.5;
  color: #333;
  margin: 0 0 40px 0;
  font-weight: 400;
}

.cta-button-large {
  background: #007AFF;
  color: white;
  border: none;
  padding: 14px 32px;
  border-radius: 24px;
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
}

.cta-button-large:hover {
  background: #0051D5;
}

@media (max-width: 1200px) {
  .feature-cards-left {
    right: calc(50% + 140px);
  }

  .feature-cards-right {
    left: calc(50% + 140px);
  }

  .card-float-1,
  .card-float-2,
  .card-float-3,
  .card-float-4,
  .card-float-5 {
    transform: translateX(60px);
  }

  .feature-cards-right .card-float-1,
  .feature-cards-right .card-float-2,
  .feature-cards-right .card-float-3,
  .feature-cards-right .card-float-4,
  .feature-cards-right .card-float-5 {
    transform: translateX(-60px);
  }
}

@media (max-width: 1000px) {
  .iphone-section {
    flex-direction: column;
    gap: 30px;
    min-height: auto;
    padding: 40px 20px;
  }

  .feature-cards-left,
  .feature-cards-right {
    position: relative;
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: center;
    left: auto;
    right: auto;
  }

  .card-float-1,
  .card-float-2,
  .card-float-3,
  .card-float-4,
  .card-float-5,
  .feature-cards-right .card-float-1,
  .feature-cards-right .card-float-2,
  .feature-cards-right .card-float-3,
  .feature-cards-right .card-float-4,
  .feature-cards-right .card-float-5 {
    transform: none;
  }

  .card-faded {
    opacity: 0.7;
  }
}

@media (max-width: 768px) {
  .nav-center {
    display: none;
  }

  .hero-title {
    font-size: 48px;
  }

  .hero-description {
    font-size: 18px;
  }

  .feature-card {
    padding: 12px 14px;
    max-width: 280px;
  }

  .feature-card-icon {
    width: 38px;
    height: 38px;
  }

  .iphone-container img {
    height: 600px;
  }
}

.feature-showcase {
  padding: 80px 40px;
  max-width: 1400px;
  margin: 0 auto;
}

.showcase-title {
  font-size: 48px;
  font-weight: 700;
  color: #1d1d1f;
  margin-bottom: 12px;
  /*40px*/
  letter-spacing: -0.02em;
}

.showcase-carousel {
  display: flex;
  gap: 12px;
  /*20*/
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
  -ms-overflow-style: none;
  padding-bottom: 20px;
  padding-top: 20px;
}

.showcase-carousel::-webkit-scrollbar {
  display: none;
}

.showcase-card {
  flex: 0 0 320px;
  background: linear-gradient(180deg, #1c1c1e 0%, #2c2c2e 100%);
  border-radius: 24px;
  padding: 28px 24px 8px 24px;
  scroll-snap-align: start;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  position: relative;
  min-height: 480px;
  transition: transform 0.3s ease;
}

.showcase-card:hover {
  transform: scale(1.02);
}

.showcase-tag {
  font-size: 13px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.6);
  margin-bottom: 8px;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.showcase-card-title {
  font-size: 24px;
  font-weight: 600;
  color: #ffffff;
  line-height: 1.25;
  margin: 0 0 16px 0;
  /*24*/
  letter-spacing: -0.01em;
}

.showcase-image-container {
  flex: 1;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  overflow: hidden;
  margin: 0 -24px;
}

.showcase-image-container img {
  width: 75%;
  height: auto;
  object-fit: contain;
  object-position: bottom;
  filter: drop-shadow(0 -10px 30px rgba(0, 0, 0, 0.3));
}

.carousel-navigation {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
}

.carousel-nav-btn {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: none;
  background: #f5f5f7;
  color: #1d1d1f;
  font-size: 24px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s, transform 0.2s;
}

.carousel-nav-btn:hover {
  background: #e8e8ed;
  transform: scale(1.05);
}

.carousel-nav-btn:active {
  transform: scale(0.95);
}

@media (max-width: 768px) {
  .feature-showcase {
    padding: 60px 20px;
  }

  .showcase-title {
    font-size: 32px;
  }

  .showcase-card {
    flex: 0 0 280px;
    min-height: 400px;
  }

  .showcase-card-title {
    font-size: 20px;
  }
}

.feature-detail-section {
  padding: 100px 40px;
  max-width: 1200px;
  margin: 0 auto;
}

.feature-detail-header {
  max-width: 700px;
  margin-bottom: 80px;
}

.feature-detail-title {
  font-size: 56px;
  font-weight: 700;
  color: #1d1d1f;
  line-height: 1.1;
  letter-spacing: -0.02em;
  margin: 0 0 24px 0;
}

.feature-detail-description {
  font-size: 19px;
  line-height: 1.6;
  color: #424245;
  margin: 0;
}

.feature-detail-content {
  display: flex;
  align-items: center;
  gap: 60px;
  background: #f5f5f7;
  border-radius: 32px;
  padding: 60px;
  min-height: 500px;
}

.feature-detail-text {
  flex: 1;
  max-width: 400px;
}

.feature-highlight-title {
  font-size: 32px;
  font-weight: 700;
  color: #1d1d1f;
  line-height: 1.2;
  letter-spacing: -0.02em;
  margin: 0 0 20px 0;
}

.feature-highlight-description {
  font-size: 17px;
  line-height: 1.6;
  color: #424245;
  margin: 0;
}

.feature-detail-phones {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
}

.phone-stack {
  position: relative;
  width: 100%;
  max-width: 500px;
  height: 450px;
}

.phone-stack img {
  position: absolute;
  height: 420px;
  width: auto;
  filter: drop-shadow(0 25px 50px rgba(0, 0, 0, 0.15));
  transition: transform 0.4s ease;
}

.phone-back {
  left: 0;
  top: 20px;
  transform: rotate(-8deg);
  z-index: 1;
}

.phone-front {
  right: 0;
  top: 0;
  transform: rotate(5deg);
  z-index: 2;
}

.phone-stack:hover .phone-back {
  transform: rotate(-12deg) translateX(-10px);
}

.phone-stack:hover .phone-front {
  transform: rotate(8deg) translateX(10px);
}

@media (max-width: 1000px) {
  .feature-detail-content {
    flex-direction: column;
    padding: 50px 40px;
  }

  .feature-detail-text {
    max-width: 100%;
    text-align: center;
  }

  .phone-stack {
    height: 380px;
  }

  .phone-stack img {
    height: 350px;
  }
}

@media (max-width: 768px) {
  .feature-detail-section {
    padding: 60px 20px;
  }

  .feature-detail-title {
    font-size: 36px;
  }

  .feature-detail-description {
    font-size: 17px;
  }

  .feature-detail-header {
    margin-bottom: 40px;
  }

  .feature-detail-content {
    padding: 40px 24px;
    gap: 40px;
  }

  .feature-highlight-title {
    font-size: 24px;
  }

  .phone-stack {
    height: 320px;
  }

  .phone-stack img {
    height: 280px;
  }

  .phone-back {
    left: 10%;
  }

  .phone-front {
    right: 10%;
  }
}

.reviews-section {
  padding: 80px 40px;
  max-width: 1400px;
  margin: 0 auto;
  position: relative;
}

.reviews-title {
  font-size: 48px;
  font-weight: 700;
  color: #1d1d1f;
  margin-bottom: 40px;
  letter-spacing: -0.02em;
  text-align: center;
}

.reviews-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  align-items: start;
  position: relative;
  max-height: 700px;
  overflow: hidden;
}

.reviews-grid::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 200px;
  background: linear-gradient(to bottom, rgba(255, 255, 255, 0) 0%, rgba(255, 255, 255, 0.8) 50%, rgba(255, 255, 255, 1) 100%);
  pointer-events: none;
  z-index: 10;
}

.reviews-column {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.review-card {
  background: #fff;
  border-radius: 20px;
  padding: 24px;
  box-shadow:
    0 0 0 1px rgba(0, 0, 0, 0.04),
    0 2px 8px rgba(0, 0, 0, 0.04),
    0 8px 24px rgba(0, 0, 0, 0.06);
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.review-card:hover {
  transform: translateY(-4px);
  box-shadow:
    0 0 0 1px rgba(0, 0, 0, 0.04),
    0 4px 16px rgba(0, 0, 0, 0.08),
    0 16px 32px rgba(0, 0, 0, 0.1);
}

.review-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.review-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  flex-shrink: 0;
}

.avatar-small {
  width: 40px;
  height: 40px;
  font-size: 20px;
}

.review-author {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.author-name {
  font-size: 16px;
  font-weight: 600;
  color: #1d1d1f;
}

.author-handle {
  font-size: 14px;
  color: #555;
}

.review-date {
  font-size: 13px;
  color: #555;
  margin-left: auto;
  white-space: nowrap;
}

.review-text {
  font-size: 15px;
  line-height: 1.5;
  color: #1d1d1f;
  margin: 0 0 12px 0;
}

.review-text:last-child {
  margin-bottom: 0;
}

.review-appstore .review-header {
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
}

.review-store-title {
  font-size: 17px;
  font-weight: 600;
  color: #1d1d1f;
}

.review-stars {
  color: #FF9500;
  font-size: 16px;
  letter-spacing: 2px;
  margin-bottom: 12px;
}

.review-video-placeholder {
  position: relative;
  border-radius: 16px;
  overflow: hidden;
  background: linear-gradient(180deg, #667eea 0%, #764ba2 100%);
  aspect-ratio: 9/12;
  margin-bottom: 16px;
}

.video-overlay {
  position: absolute;
  top: 16px;
  left: 16px;
  right: 16px;
  z-index: 2;
}

.video-caption {
  background: rgba(0, 0, 0, 0.6);
  color: white;
  padding: 8px 14px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
}

.video-preview-img {
  position: absolute;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 60%;
  height: auto;
}

.review-social-footer {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.social-avatars {
  display: flex;
  margin-right: 4px;
}

.mini-avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #e0e0e0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  margin-left: -6px;
  border: 2px solid white;
}

.mini-avatar:first-child {
  margin-left: 0;
}

.social-stat {
  font-size: 13px;
  color: #555;
  flex: 1;
}

.view-more-btn {
  background: #1d1d1f;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.view-more-btn:hover {
  background: #333;
}

@media (max-width: 1000px) {
  .reviews-grid {
    grid-template-columns: repeat(2, 1fr);
    max-height: 800px;
  }
}

@media (max-width: 768px) {
  .reviews-section {
    padding: 60px 20px;
  }

  .reviews-title {
    font-size: 32px;
  }

  .reviews-grid {
    grid-template-columns: 1fr;
    max-height: none;
  }

  .reviews-grid::after {
    display: none;
  }

  .review-card {
    padding: 20px;
  }
}
</style>
