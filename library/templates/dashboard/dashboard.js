// TOC Navigation
function toggleToc() {
    const toc = document.getElementById('toc');
    const currentLeft = window.getComputedStyle(toc).left;
    toc.style.transform = currentLeft === '20px' ? 'translateX(-100%)' : 'translateX(0)';
}

// Smooth scroll
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});

// Highlight active section in TOC
function highlightToc() {
    const sections = document.querySelectorAll('.section');
    const tocLinks = document.querySelectorAll('.toc a');
    
    let currentSection = '';
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.clientHeight;
        if (window.pageYOffset >= sectionTop - 100) {
            currentSection = section.getAttribute('id');
        }
    });

    tocLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href') === '#' + currentSection) {
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
        card.addEventListener('click', function(e) {
            if (e.target.tagName === 'A' || e.target.closest('a')) {
                return;
            }
            this.style.transform = 'scale(1.02)';
            setTimeout(() => {
                this.style.transform = 'translateY(-4px)';
            }, 200);
        });
    });
});

// Update timestamp periodically
function updateTimestamp() {
    const now = new Date();
    const timeString = now.toLocaleString();
    document.title = 'AitherZero Dashboard - Updated ' + timeString;
}
setInterval(updateTimestamp, 60000); // Update every minute
