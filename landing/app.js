/**
 * JANE LANDING PAGE — INTERACTIONS
 * Mobile menu, form handling, scroll animations, analytics
 */

// ========================================
// MOBILE MENU TOGGLE
// ========================================

function initMobileMenu() {
  const toggle = document.getElementById('mobileMenuToggle');
  const navLinks = document.getElementById('navLinks');

  if (!toggle) return;

  toggle.addEventListener('click', () => {
    navLinks.classList.toggle('active');
    toggle.classList.toggle('active');
  });

  // Close menu when link clicked
  const links = navLinks.querySelectorAll('.nav-link');
  links.forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('active');
      toggle.classList.remove('active');
    });
  });

  // Close menu on resize
  window.addEventListener('resize', () => {
    if (window.innerWidth > 768) {
      navLinks.classList.remove('active');
      toggle.classList.remove('active');
    }
  });
}

// ========================================
// EMAIL SIGNUP FORM
// ========================================

function initEmailForm() {
  const form = document.getElementById('signupForm');
  if (!form) return;

  form.addEventListener('submit', (e) => {
    e.preventDefault();

    const emailInput = form.querySelector('.email-input');
    const email = emailInput.value.trim();

    if (!isValidEmail(email)) {
      showMessage(form, 'Please enter a valid email', 'error');
      return;
    }

    // Simulate form submission
    showMessage(form, 'Thanks! We\'ll notify you on launch day.', 'success');

    // Reset form after delay
    setTimeout(() => {
      form.reset();
      const message = form.querySelector('.form-message');
      if (message) message.remove();
    }, 3000);

    // TODO: Phase 2 - Integrate with Mailchimp API
    console.log('Email signup:', email);
    trackEvent('email_signup', { email });
  });
}

function isValidEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function showMessage(form, text, type) {
  // Remove existing message
  const existing = form.querySelector('.form-message');
  if (existing) existing.remove();

  const message = document.createElement('p');
  message.className = `form-message form-message-${type}`;
  message.textContent = text;
  message.style.cssText = `
    margin-top: 1rem;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    background: ${type === 'success' ? 'rgba(34, 197, 94, 0.1)' : 'rgba(239, 68, 68, 0.1)'};
    color: ${type === 'success' ? '#22c55e' : '#ef4444'};
    border: 1px solid ${type === 'success' ? '#22c55e' : '#ef4444'};
    font-size: 0.875rem;
    animation: slideDown 300ms ease-out;
  `;

  form.appendChild(message);
}

// ========================================
// SCROLL ANIMATIONS
// ========================================

function initScrollAnimations() {
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -100px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animate-in');
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  // Observe all feature cards
  document.querySelectorAll('.feature-card').forEach(card => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    card.style.transition = 'opacity 600ms ease-out, transform 600ms ease-out';
    observer.observe(card);
  });

  // Observe proof cards
  document.querySelectorAll('.proof-card').forEach((card, index) => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    card.style.transition = `opacity 600ms ease-out ${index * 100}ms, transform 600ms ease-out ${index * 100}ms`;
    observer.observe(card);
  });

  // Observe pricing cards
  document.querySelectorAll('.pricing-card').forEach((card, index) => {
    card.style.opacity = '0';
    card.style.transform = 'translateY(20px)';
    card.style.transition = `opacity 600ms ease-out ${index * 100}ms, transform 600ms ease-out ${index * 100}ms`;
    observer.observe(card);
  });
}

// Animation in class
document.addEventListener('DOMContentLoaded', () => {
  const style = document.createElement('style');
  style.textContent = `
    .animate-in {
      opacity: 1 !important;
      transform: translateY(0) !important;
    }

    @keyframes slideDown {
      from {
        opacity: 0;
        transform: translateY(-10px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
  `;
  document.head.appendChild(style);
});

// ========================================
// STICKY NAVBAR BEHAVIOR
// ========================================

function initNavbar() {
  const navbar = document.querySelector('.navbar');
  let lastScrollTop = 0;

  window.addEventListener('scroll', () => {
    const scrollTop = window.scrollY;

    // Add subtle shadow on scroll
    if (scrollTop > 10) {
      navbar.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.1)';
    } else {
      navbar.style.boxShadow = 'none';
    }

    lastScrollTop = scrollTop;
  });
}

// ========================================
// UTILITY: SCROLL TO SECTION
// ========================================

function scrollToSection(id) {
  const element = document.getElementById(id);
  if (element) {
    element.scrollIntoView({ behavior: 'smooth' });
  }
}

// Make scrollToSection globally available
window.scrollToSection = scrollToSection;

// ========================================
// ANALYTICS TRACKING (Phase 2 integration)
// ========================================

function trackEvent(eventName, eventData = {}) {
  // TODO: Phase 2 - Integrate with Google Analytics 4
  if (window.gtag) {
    window.gtag('event', eventName, eventData);
  }

  // TODO: Phase 2 - Integrate with Segment
  if (window.analytics) {
    window.analytics.track(eventName, eventData);
  }

  // Development logging
  console.log(`[Analytics] ${eventName}`, eventData);
}

function trackPageView(path) {
  // TODO: Phase 2 - Integrate with Google Analytics 4
  if (window.gtag) {
    window.gtag('config', 'G-PLACEHOLDER', {
      page_path: path
    });
  }

  console.log(`[Analytics] Page view: ${path}`);
}

// ========================================
// BUTTON TRACKING
// ========================================

function initButtonTracking() {
  // Track external link clicks
  document.querySelectorAll('a[target="_blank"]').forEach(link => {
    link.addEventListener('click', () => {
      const href = link.getAttribute('href');
      const text = link.textContent;

      trackEvent('external_link_click', {
        url: href,
        text: text
      });
    });
  });

  // Track CTA button clicks
  document.querySelectorAll('.btn-primary, .btn-secondary').forEach(btn => {
    btn.addEventListener('click', () => {
      trackEvent('cta_click', {
        text: btn.textContent.trim(),
        type: btn.classList.contains('btn-primary') ? 'primary' : 'secondary'
      });
    });
  });
}

// ========================================
// PERFORMANCE MONITORING
// ========================================

function initPerformanceMonitoring() {
  if ('PerformanceObserver' in window) {
    try {
      // Monitor largest contentful paint (LCP)
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const lastEntry = entries[entries.length - 1];

        if (lastEntry.renderTime) {
          console.log(`[Performance] LCP: ${lastEntry.renderTime.toFixed(0)}ms`);
        }
      });

      lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] });

      // Monitor cumulative layout shift (CLS)
      let clsValue = 0;
      const clsObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) {
            clsValue += entry.value;
            console.log(`[Performance] CLS: ${clsValue.toFixed(3)}`);
          }
        }
      });

      clsObserver.observe({ entryTypes: ['layout-shift'] });
    } catch (e) {
      console.log('[Performance] Observer not supported');
    }
  }
}

// ========================================
// THEME DETECTION & SETUP
// ========================================

function initTheme() {
  // Detect system theme preference
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const prefersLight = window.matchMedia('(prefers-color-scheme: light)').matches;

  console.log(`[Theme] System preference: ${prefersDark ? 'dark' : 'light'}`);

  // Watch for theme changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
    console.log(`[Theme] Changed to: ${e.matches ? 'dark' : 'light'}`);
  });
}

// ========================================
// INITIALIZATION
// ========================================

document.addEventListener('DOMContentLoaded', () => {
  console.log('[Jane] Landing page initialized');

  // Core functionality
  initMobileMenu();
  initEmailForm();
  initNavbar();
  initScrollAnimations();
  initButtonTracking();
  initTheme();

  // Performance monitoring (dev mode)
  if (process.env.NODE_ENV !== 'production') {
    initPerformanceMonitoring();
  }

  // Track page view
  trackPageView(window.location.pathname);

  // Log page ready
  console.log('[Jane] Page ready and interactive');
});

// ========================================
// UNHANDLED ERROR TRACKING
// ========================================

window.addEventListener('error', (event) => {
  trackEvent('javascript_error', {
    message: event.message,
    source: event.filename,
    lineno: event.lineno,
    colno: event.colno
  });

  console.error('[Error]', event.error);
});

window.addEventListener('unhandledrejection', (event) => {
  trackEvent('unhandled_promise_rejection', {
    reason: event.reason.toString()
  });

  console.error('[Unhandled Rejection]', event.reason);
});

// ========================================
// EXPORT FOR TESTING
// ========================================

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    initMobileMenu,
    initEmailForm,
    isValidEmail,
    scrollToSection,
    trackEvent
  };
}
