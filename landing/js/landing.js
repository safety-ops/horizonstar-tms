/**
 * VroomX TMS Landing Page JavaScript
 * Handles all interactions, animations, and dynamic functionality
 */

(function() {
    'use strict';

    // ============================================
    // DOM Elements
    // ============================================
    const navbar = document.getElementById('navbar');
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileMenu = document.getElementById('mobileMenu');
    const billingToggle = document.getElementById('billingToggle');
    const faqItems = document.querySelectorAll('.faq-item');
    const statNumbers = document.querySelectorAll('.stat-number[data-count]');
    const aosElements = document.querySelectorAll('[data-aos]');

    // ============================================
    // Navigation
    // ============================================

    // Sticky navbar on scroll
    function handleNavbarScroll() {
        if (window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    }

    window.addEventListener('scroll', handleNavbarScroll);
    handleNavbarScroll(); // Check on load

    // Mobile menu toggle
    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', function() {
            this.classList.toggle('active');
            mobileMenu.classList.toggle('active');
            document.body.style.overflow = mobileMenu.classList.contains('active') ? 'hidden' : '';
        });

        // Close mobile menu when clicking a link
        mobileMenu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', function() {
                mobileMenuBtn.classList.remove('active');
                mobileMenu.classList.remove('active');
                document.body.style.overflow = '';
            });
        });
    }

    // ============================================
    // Smooth Scroll
    // ============================================
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const href = this.getAttribute('href');
            if (href === '#') return;

            e.preventDefault();
            const target = document.querySelector(href);

            if (target) {
                const navbarHeight = navbar.offsetHeight;
                const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navbarHeight - 20;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });

    // ============================================
    // Pricing Toggle (Monthly/Annual)
    // ============================================
    if (billingToggle) {
        const toggleLabels = document.querySelectorAll('.toggle-label');
        const priceAmounts = document.querySelectorAll('.plan-price .amount[data-monthly]');

        function updatePricing(isAnnual) {
            // Update toggle labels
            toggleLabels.forEach(label => {
                const period = label.getAttribute('data-period');
                if ((period === 'annual' && isAnnual) || (period === 'monthly' && !isAnnual)) {
                    label.classList.add('active');
                } else {
                    label.classList.remove('active');
                }
            });

            // Update prices with animation
            priceAmounts.forEach(amount => {
                const monthly = amount.getAttribute('data-monthly');
                const annual = amount.getAttribute('data-annual');
                const newValue = isAnnual ? annual : monthly;

                // Animate the number change
                animateValue(amount, parseInt(amount.textContent), parseInt(newValue), 300);
            });
        }

        billingToggle.addEventListener('change', function() {
            updatePricing(this.checked);
        });

        // Initialize
        updatePricing(billingToggle.checked);
    }

    // Animate value change
    function animateValue(element, start, end, duration) {
        const startTime = performance.now();

        function update(currentTime) {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);

            // Easing function (ease-out)
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const current = Math.round(start + (end - start) * easeOut);

            element.textContent = current;

            if (progress < 1) {
                requestAnimationFrame(update);
            }
        }

        requestAnimationFrame(update);
    }

    // ============================================
    // FAQ Accordion
    // ============================================
    faqItems.forEach(item => {
        const question = item.querySelector('.faq-question');

        question.addEventListener('click', function() {
            const isActive = item.classList.contains('active');

            // Close all other items (optional - remove for multi-open)
            faqItems.forEach(otherItem => {
                if (otherItem !== item) {
                    otherItem.classList.remove('active');
                    otherItem.querySelector('.faq-question').setAttribute('aria-expanded', 'false');
                }
            });

            // Toggle current item
            item.classList.toggle('active');
            this.setAttribute('aria-expanded', !isActive);
        });
    });

    // ============================================
    // Stats Counter Animation
    // ============================================
    function animateStats() {
        statNumbers.forEach(stat => {
            const target = parseInt(stat.getAttribute('data-count'));
            const duration = 2000; // 2 seconds
            const startTime = performance.now();

            function updateCount(currentTime) {
                const elapsed = currentTime - startTime;
                const progress = Math.min(elapsed / duration, 1);

                // Easing function (ease-out-expo)
                const easeOutExpo = progress === 1 ? 1 : 1 - Math.pow(2, -10 * progress);
                const current = Math.round(target * easeOutExpo);

                stat.textContent = current.toLocaleString();

                if (progress < 1) {
                    requestAnimationFrame(updateCount);
                }
            }

            requestAnimationFrame(updateCount);
        });
    }

    // ============================================
    // Intersection Observer for Animations
    // ============================================
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    // Stats animation observer
    const statsObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateStats();
                statsObserver.disconnect();
            }
        });
    }, observerOptions);

    const statsContainer = document.querySelector('.hero-stats');
    if (statsContainer) {
        statsObserver.observe(statsContainer);
    }

    // AOS (Animate On Scroll) observer
    const aosObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                // Add delay based on data-aos-delay attribute
                const delay = entry.target.getAttribute('data-aos-delay') || 0;
                setTimeout(() => {
                    entry.target.classList.add('aos-animate');
                }, parseInt(delay));
            }
        });
    }, {
        root: null,
        rootMargin: '0px',
        threshold: 0.15
    });

    aosElements.forEach(element => {
        aosObserver.observe(element);
    });

    // ============================================
    // Navbar Link Active State
    // ============================================
    const sections = document.querySelectorAll('section[id]');

    function setActiveNavLink() {
        const scrollPosition = window.scrollY + navbar.offsetHeight + 100;

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id');

            if (scrollPosition >= sectionTop && scrollPosition < sectionTop + sectionHeight) {
                document.querySelectorAll('.nav-links a').forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${sectionId}`) {
                        link.classList.add('active');
                    }
                });
            }
        });
    }

    window.addEventListener('scroll', setActiveNavLink);

    // ============================================
    // Parallax Effect on Hero Glow
    // ============================================
    const heroGlow = document.querySelector('.hero-glow');

    if (heroGlow) {
        window.addEventListener('mousemove', function(e) {
            const moveX = (e.clientX - window.innerWidth / 2) * 0.02;
            const moveY = (e.clientY - window.innerHeight / 2) * 0.02;

            heroGlow.style.transform = `translate(calc(-50% + ${moveX}px), ${moveY}px)`;
        });
    }

    // ============================================
    // Dashboard Mockup Bar Animation
    // ============================================
    function animateBars() {
        const bars = document.querySelectorAll('.chart-bars .bar');
        bars.forEach((bar, index) => {
            const originalHeight = bar.style.height;
            bar.style.height = '0%';

            setTimeout(() => {
                bar.style.transition = 'height 0.8s cubic-bezier(0.4, 0, 0.2, 1)';
                bar.style.height = originalHeight;
            }, 100 * index);
        });
    }

    // Animate bars when mockup comes into view
    const mockup = document.querySelector('.dashboard-mockup');
    if (mockup) {
        const mockupObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    setTimeout(animateBars, 500);
                    mockupObserver.disconnect();
                }
            });
        }, { threshold: 0.3 });

        mockupObserver.observe(mockup);
    }

    // ============================================
    // Form Submission (if needed for CTAs)
    // ============================================
    document.querySelectorAll('form').forEach(form => {
        form.addEventListener('submit', function(e) {
            e.preventDefault();
            // Handle form submission here
            console.log('Form submitted');
        });
    });

    // ============================================
    // Keyboard Navigation
    // ============================================
    document.addEventListener('keydown', function(e) {
        // Close mobile menu on Escape
        if (e.key === 'Escape' && mobileMenu.classList.contains('active')) {
            mobileMenuBtn.classList.remove('active');
            mobileMenu.classList.remove('active');
            document.body.style.overflow = '';
        }
    });

    // ============================================
    // Preloader (optional)
    // ============================================
    window.addEventListener('load', function() {
        document.body.classList.add('loaded');

        // Trigger initial animations
        setTimeout(() => {
            document.querySelectorAll('.animate-fade-in, .animate-fade-in-up').forEach(el => {
                el.style.animationPlayState = 'running';
            });
        }, 100);
    });

    // ============================================
    // Console Branding
    // ============================================
    console.log('%c🚛 VroomX TMS', 'font-size: 24px; font-weight: bold; color: #dc2626;');
    console.log('%cDrive Your Fleet Forward', 'font-size: 14px; color: #666;');
    console.log('%chttps://vroomxtms.com', 'font-size: 12px; color: #999;');

})();
