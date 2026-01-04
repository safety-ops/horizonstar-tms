/**
 * VroomX Landing Page JavaScript
 * Handles navigation, smooth scroll, and interactions
 */

document.addEventListener('DOMContentLoaded', () => {
    // Mobile navigation toggle
    const mobileToggle = document.querySelector('.nav-mobile-toggle');
    const navLinks = document.querySelector('.nav-links');
    const navActions = document.querySelector('.nav-actions');

    if (mobileToggle) {
        mobileToggle.addEventListener('click', () => {
            mobileToggle.classList.toggle('active');
            navLinks?.classList.toggle('mobile-open');
            navActions?.classList.toggle('mobile-open');
        });
    }

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const href = anchor.getAttribute('href');
            if (href === '#') return;

            e.preventDefault();
            const target = document.querySelector(href);
            if (target) {
                const navHeight = document.querySelector('.navbar')?.offsetHeight || 0;
                const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });

                // Close mobile menu if open
                mobileToggle?.classList.remove('active');
                navLinks?.classList.remove('mobile-open');
                navActions?.classList.remove('mobile-open');
            }
        });
    });

    // Navbar scroll effect
    const navbar = document.querySelector('.navbar');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        if (currentScroll > 50) {
            navbar?.classList.add('scrolled');
        } else {
            navbar?.classList.remove('scrolled');
        }

        lastScroll = currentScroll;
    });

    // Intersection Observer for animations
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe feature cards and other elements
    document.querySelectorAll('.feature-card, .pricing-card, .testimonial-card, .stat-item').forEach(el => {
        observer.observe(el);
    });

    // Add animation styles dynamically
    const style = document.createElement('style');
    style.textContent = `
        .feature-card,
        .pricing-card,
        .testimonial-card,
        .stat-item {
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.5s ease, transform 0.5s ease;
        }

        .feature-card.animate-in,
        .pricing-card.animate-in,
        .testimonial-card.animate-in,
        .stat-item.animate-in {
            opacity: 1;
            transform: translateY(0);
        }

        .nav-links.mobile-open,
        .nav-actions.mobile-open {
            display: flex !important;
            position: absolute;
            top: 100%;
            left: 0;
            right: 0;
            flex-direction: column;
            background: white;
            padding: 1rem;
            border-top: 1px solid #e5e5e5;
            box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
        }

        .nav-links.mobile-open {
            gap: 0;
        }

        .nav-links.mobile-open a {
            padding: 0.75rem 0;
            border-bottom: 1px solid #f5f5f5;
        }

        .nav-actions.mobile-open {
            border-top: none;
            padding-top: 0;
        }

        .nav-mobile-toggle.active span:nth-child(1) {
            transform: rotate(45deg) translate(5px, 5px);
        }

        .nav-mobile-toggle.active span:nth-child(2) {
            opacity: 0;
        }

        .nav-mobile-toggle.active span:nth-child(3) {
            transform: rotate(-45deg) translate(5px, -5px);
        }

        .navbar.scrolled {
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }

        @media (min-width: 769px) {
            .nav-links.mobile-open,
            .nav-actions.mobile-open {
                display: flex !important;
                position: static;
                flex-direction: row;
                background: transparent;
                padding: 0;
                border: none;
                box-shadow: none;
            }
        }
    `;
    document.head.appendChild(style);

    // Console branding
    console.log('%cVroomX TMS', 'font-size: 24px; font-weight: bold; color: #000;');
    console.log('%cFleet Management at Full Speed', 'font-size: 14px; color: #666;');
});
