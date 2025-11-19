// Cloud Resume Challenge - Visitor Counter Script

// API Configuration
const API_ENDPOINT = 'https://api.resume.yourdomain.com'; // Update with your actual API endpoint

// DOM Elements
const visitorCountElement = document.getElementById('visitor-count');

/**
 * Animate counter from start to end value
 * @param {HTMLElement} element - DOM element to update
 * @param {number} start - Starting value
 * @param {number} end - Ending value
 * @param {number} duration - Animation duration in milliseconds
 */
function animateCounter(element, start, end, duration) {
    const startTime = performance.now();
    const difference = end - start;

    function updateCounter(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);

        // Easing function for smooth animation
        const easeOutQuad = progress * (2 - progress);
        const currentValue = Math.floor(start + difference * easeOutQuad);

        element.textContent = currentValue.toLocaleString();

        if (progress < 1) {
            requestAnimationFrame(updateCounter);
        } else {
            element.textContent = end.toLocaleString();
        }
    }

    requestAnimationFrame(updateCounter);
}

/**
 * Fetch and update visitor count from API
 */
async function updateVisitorCount() {
    try {
        // Show loading state
        visitorCountElement.textContent = '...';

        // Call API to increment visitor count
        const response = await fetch(`${API_ENDPOINT}/visitors`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            mode: 'cors',
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        const visitorCount = data.count;

        // Animate counter from 0 to actual count
        animateCounter(visitorCountElement, 0, visitorCount, 1000);

        // Log success for debugging
        console.log(`✅ Visitor count updated: ${visitorCount}`);
    } catch (error) {
        console.error('❌ Error fetching visitor count:', error);
        visitorCountElement.textContent = 'Error';

        // Show user-friendly error message
        showErrorNotification('Unable to load visitor count. Please try refreshing the page.');
    }
}

/**
 * Show error notification to user
 * @param {string} message - Error message to display
 */
function showErrorNotification(message) {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = 'error-notification';
    notification.textContent = message;
    notification.style.cssText = `
        position: fixed;
        bottom: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: #ef4444;
        color: white;
        padding: 1rem 2rem;
        border-radius: 8px;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
        z-index: 1001;
        animation: slideUp 0.3s ease-out;
    `;

    // Add animation keyframes
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideUp {
            from {
                transform: translateX(-50%) translateY(100px);
                opacity: 0;
            }
            to {
                transform: translateX(-50%) translateY(0);
                opacity: 1;
            }
        }
    `;
    document.head.appendChild(style);

    // Add to DOM
    document.body.appendChild(notification);

    // Remove after 5 seconds
    setTimeout(() => {
        notification.style.animation = 'slideUp 0.3s ease-out reverse';
        setTimeout(() => {
            document.body.removeChild(notification);
            document.head.removeChild(style);
        }, 300);
    }, 5000);
}

/**
 * Add smooth scroll behavior for anchor links
 */
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
}

/**
 * Add intersection observer for fade-in animations
 */
function initScrollAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.animation = 'fadeInUp 0.6s ease-out forwards';
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe all sections
    document.querySelectorAll('.section').forEach(section => {
        section.style.opacity = '0';
        observer.observe(section);
    });

    // Add animation keyframes
    const style = document.createElement('style');
    style.textContent = `
        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
    `;
    document.head.appendChild(style);
}

/**
 * Track performance metrics
 */
function trackPerformance() {
    if ('performance' in window) {
        window.addEventListener('load', () => {
            const perfData = performance.timing;
            const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
            console.log(`📊 Page load time: ${pageLoadTime}ms`);
        });
    }
}

/**
 * Initialize all features when DOM is ready
 */
function init() {
    console.log('🚀 Cloud Resume Challenge - Initializing...');

    // Update visitor count
    updateVisitorCount();

    // Initialize smooth scrolling
    initSmoothScroll();

    // Initialize scroll animations
    initScrollAnimations();

    // Track performance
    trackPerformance();

    console.log('✅ Initialization complete');
}

// Run initialization when DOM is fully loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}

// Retry visitor count update on focus (if user returns to tab)
window.addEventListener('focus', () => {
    if (visitorCountElement.textContent === 'Error') {
        console.log('🔄 Retrying visitor count update...');
        updateVisitorCount();
    }
});
