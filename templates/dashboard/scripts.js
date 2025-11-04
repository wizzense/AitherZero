        // TOC toggle for mobile
        function toggleToc() {
            document.getElementById('toc').classList.toggle('open');
        }

        // Roadmap priority toggle
        function togglePriority(id) {
            const content = document.getElementById(id);
            const header = content.previousElementSibling;
            
            if (content.style.display === 'none' || content.style.display === '') {
                content.style.display = 'block';
                header.classList.add('active');
            } else {
                content.style.display = 'none';
                header.classList.remove('active');
            }
        }

        // Highlight active section in TOC
        const sections = document.querySelectorAll('.section, .header');
        const tocLinks = document.querySelectorAll('.toc a');

        function highlightToc() {
            let current = '';
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionHeight = section.clientHeight;
                if (pageYOffset >= sectionTop - 100) {
                    current = section.getAttribute('id');
                }
            });

            tocLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === '#' + current) {
                    link.classList.add('active');
                }
            });
        }

        window.addEventListener('scroll', highlightToc);
        highlightToc();

        // Interactive card expansion
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.metric-card');
            cards.forEach(card => {
                // Add click animation
                card.addEventListener('click', function(e) {
                    // Don't expand if clicking on a link
                    if (e.target.tagName === 'A' || e.target.closest('a')) {
                        return;
                    }
                    
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
                    }, 150);
                });

                // Add hover effects
                card.addEventListener('mouseenter', function() {
                    this.style.boxShadow = '0 8px 25px rgba(102, 126, 234, 0.25)';
                });

                card.addEventListener('mouseleave', function() {
                    this.style.boxShadow = '';
                });
            });

            // Smooth scroll for TOC links
            document.querySelectorAll('.toc a').forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const targetId = this.getAttribute('href').substring(1);
                    const targetElement = document.getElementById(targetId);
                    
                    if (targetElement) {
                        targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        // Close mobile TOC after navigation
                        if (window.innerWidth < 768) {
                            document.getElementById('toc').classList.remove('open');
                        }
                    }
                });
            });

            // Add copy-to-clipboard for code blocks
            document.querySelectorAll('code').forEach(code => {
                code.style.cursor = 'pointer';
                code.title = 'Click to copy';
                code.addEventListener('click', function() {
                    navigator.clipboard.writeText(this.textContent).then(() => {
                        const originalText = this.textContent;
                        this.textContent = '✓ Copied!';
                        setTimeout(() => {
                            this.textContent = originalText;
                        }, 1500);
                    });
                });
            });

            // Animate progress bars on scroll
            const progressBars = document.querySelectorAll('.progress-fill');
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.style.transition = 'width 1.5s ease-out';
                        const width = entry.target.style.width;
                        entry.target.style.width = '0%';
                        setTimeout(() => {
                            entry.target.style.width = width;
                        }, 100);
                    }
                });
            }, { threshold: 0.5 });

            progressBars.forEach(bar => observer.observe(bar));

            // Add keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                // Ctrl/Cmd + K to toggle TOC
                if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                    e.preventDefault();
                    toggleToc();
                }
                // Escape to close TOC
                if (e.key === 'Escape') {
                    document.getElementById('toc').classList.remove('open');
                }
            });

            // Add search functionality hint (for future enhancement)
            console.log('💡 Dashboard Pro Tip: Use Ctrl+F to search this dashboard');
            console.log('🔍 Keyboard shortcuts:');
            console.log('  - Ctrl/Cmd + K: Toggle navigation');
            console.log('  - Escape: Close navigation');
            console.log('  - Click code blocks to copy');
        });

        // Auto-refresh every 5 minutes (optional - can be disabled)
        // setTimeout(() => {
        //     window.location.reload();
        // }, 300000);

        // Add live timestamp update
        function updateTimestamp() {
            const now = new Date();
            const timeString = now.toLocaleString();
            document.title = 'AitherZero Dashboard - Updated ' + timeString;
        }
        setInterval(updateTimestamp, 60000); // Update every minute
