// ============================================================================
// AitherZero Interactive Dashboard - Enhanced Scripts
// ============================================================================

// Global state management
const DashboardState = {
    currentView: 'overview',
    filters: {},
    expandedSections: new Set(),
    searchResults: [],
    dependencyGraph: null,
    configExplorer: null
};

// ============================================================================
// Core Navigation & TOC
// ============================================================================

function toggleToc() {
    const toc = document.getElementById('toc');
    if (toc) {
        toc.classList.toggle('open');
    }
}

function highlightToc() {
    const sections = document.querySelectorAll('.section, .header');
    const tocLinks = document.querySelectorAll('.toc a');
    
    let current = '';
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        if (window.pageYOffset >= sectionTop - 100) {
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

// ============================================================================
// Breadcrumb Navigation
// ============================================================================

function initBreadcrumbs() {
    const breadcrumbContainer = document.getElementById('breadcrumbs');
    if (!breadcrumbContainer) return;
    
    // Build breadcrumb trail based on current section
    window.addEventListener('scroll', updateBreadcrumbs);
    updateBreadcrumbs();
}

function updateBreadcrumbs() {
    const breadcrumbContainer = document.getElementById('breadcrumbs');
    if (!breadcrumbContainer) return;
    
    const sections = document.querySelectorAll('.section, .header');
    let currentSection = null;
    
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        if (window.pageYOffset >= sectionTop - 150) {
            currentSection = section;
        }
    });
    
    if (currentSection) {
        const sectionId = currentSection.getAttribute('id');
        const sectionTitle = currentSection.querySelector('h2, h1')?.textContent || sectionId;
        
        breadcrumbContainer.innerHTML = `
            <a href="#top" class="breadcrumb-item">🏠 Dashboard</a>
            <span class="breadcrumb-separator">›</span>
            <a href="#${sectionId}" class="breadcrumb-item active">${sectionTitle}</a>
        `;
    }
}

// ============================================================================
// Interactive Dependency Visualization
// ============================================================================

function initDependencyGraph(dependencyData) {
    const container = document.getElementById('dependency-graph');
    if (!container || !dependencyData) return;
    
    DashboardState.dependencyGraph = dependencyData;
    renderDependencyGraph(dependencyData);
}

function renderDependencyGraph(data) {
    const container = document.getElementById('dependency-graph');
    if (!container) return;
    
    container.innerHTML = '<div class="graph-loading">Rendering dependency graph...</div>';
    
    // Create interactive network visualization
    setTimeout(() => {
        const graphHTML = createDependencyGraphHTML(data);
        container.innerHTML = graphHTML;
        attachDependencyHandlers();
    }, 100);
}

function createDependencyGraphHTML(data) {
    let html = '<div class="dependency-network">';
    
    // Group by domain
    const domains = {};
    Object.keys(data).forEach(script => {
        const deps = data[script];
        const domain = script.split('/')[0] || 'core';
        if (!domains[domain]) domains[domain] = [];
        domains[domain].push({ script, deps });
    });
    
    // Render domains
    Object.keys(domains).sort().forEach(domain => {
        html += `
            <div class="dependency-domain" data-domain="${domain}">
                <div class="domain-header" onclick="toggleDependencyDomain('${domain}')">
                    <span class="toggle-icon">▼</span>
                    <h4>📦 ${domain}</h4>
                    <span class="badge">${domains[domain].length} scripts</span>
                </div>
                <div class="domain-content" id="deps-${domain}">
        `;
        
        domains[domain].forEach(({ script, deps }) => {
            const depsCount = Array.isArray(deps) ? deps.length : 0;
            html += `
                <div class="dependency-item" data-script="${script}">
                    <div class="script-name" onclick="showDependencyDetails('${script}')">
                        📄 ${script}
                        ${depsCount > 0 ? `<span class="deps-badge">${depsCount} deps</span>` : ''}
                    </div>
                    ${depsCount > 0 ? `
                        <div class="dependency-list" id="deps-list-${script.replace(/[^a-zA-Z0-9]/g, '_')}">
                            ${deps.map(dep => `<div class="dep-link" onclick="navigateToDependency('${dep}')">→ ${dep}</div>`).join('')}
                        </div>
                    ` : ''}
                </div>
            `;
        });
        
        html += '</div></div>';
    });
    
    html += '</div>';
    return html;
}

function toggleDependencyDomain(domain) {
    const content = document.getElementById(`deps-${domain}`);
    const header = content?.previousElementSibling;
    
    if (content && header) {
        const isOpen = content.style.display !== 'none';
        content.style.display = isOpen ? 'none' : 'block';
        header.querySelector('.toggle-icon').textContent = isOpen ? '▶' : '▼';
    }
}

function showDependencyDetails(script) {
    const modal = createModal(`Dependency Details: ${script}`, `
        <div class="dependency-details">
            <h4>Direct Dependencies</h4>
            <div id="direct-deps"></div>
            <h4>Reverse Dependencies (Used By)</h4>
            <div id="reverse-deps"></div>
            <h4>Dependency Chain</h4>
            <div id="dep-chain"></div>
        </div>
    `);
    
    // Calculate and show dependencies
    const deps = DashboardState.dependencyGraph[script] || [];
    document.getElementById('direct-deps').innerHTML = deps.length > 0 
        ? deps.map(d => `<div class="dep-item">→ ${d}</div>`).join('') 
        : '<em>No direct dependencies</em>';
    
    // Find reverse dependencies
    const reverseDeps = Object.keys(DashboardState.dependencyGraph).filter(s => 
        (DashboardState.dependencyGraph[s] || []).includes(script)
    );
    document.getElementById('reverse-deps').innerHTML = reverseDeps.length > 0
        ? reverseDeps.map(d => `<div class="dep-item">← ${d}</div>`).join('')
        : '<em>Not used by any scripts</em>';
}

function navigateToDependency(dep) {
    const element = document.querySelector(`[data-script="${dep}"]`);
    if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        element.classList.add('highlight-flash');
        setTimeout(() => element.classList.remove('highlight-flash'), 2000);
    }
}

function attachDependencyHandlers() {
    // Handlers are attached via onclick in HTML for better compatibility
}

// ============================================================================
// Domain Module Explorer
// ============================================================================

function initDomainExplorer(domainData) {
    const container = document.getElementById('domain-explorer');
    if (!container || !domainData) return;
    
    renderDomainExplorer(domainData);
}

function renderDomainExplorer(data) {
    const container = document.getElementById('domain-explorer');
    if (!container) return;
    
    let html = '<div class="domain-explorer-grid">';
    
    data.forEach(domain => {
        html += `
            <div class="domain-card" data-domain="${domain.Name}">
                <div class="domain-card-header" onclick="toggleDomainCard('${domain.Name}')">
                    <h3>🗂️ ${domain.Name}</h3>
                    <span class="badge">${domain.Modules} modules</span>
                    <span class="toggle-icon">▼</span>
                </div>
                <div class="domain-card-content" id="domain-${domain.Name}">
                    <div class="domain-stats">
                        <div class="stat-item">
                            <span class="stat-label">Modules:</span>
                            <span class="stat-value">${domain.Modules}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Functions:</span>
                            <span class="stat-value">${domain.Functions || 'N/A'}</span>
                        </div>
                    </div>
                    <button class="btn-explore" onclick="exploreDomain('${domain.Name}')">
                        🔍 Explore Domain
                    </button>
                </div>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

function toggleDomainCard(domainName) {
    const content = document.getElementById(`domain-${domainName}`);
    const card = content?.closest('.domain-card');
    
    if (content && card) {
        const isOpen = content.style.display !== 'none';
        content.style.display = isOpen ? 'none' : 'block';
        card.querySelector('.toggle-icon').textContent = isOpen ? '▶' : '▼';
    }
}

function exploreDomain(domainName) {
    createModal(`Domain: ${domainName}`, `
        <div class="domain-details">
            <h4>📂 Module Files</h4>
            <div id="domain-files"></div>
            <h4>🔧 Exported Functions</h4>
            <div id="domain-functions"></div>
            <h4>📊 Domain Metrics</h4>
            <div id="domain-metrics"></div>
        </div>
    `);
    
    // This would be populated with actual data from the dashboard
    document.getElementById('domain-files').innerHTML = '<em>Loading module information...</em>';
}

// ============================================================================
// Configuration Explorer
// ============================================================================

function initConfigExplorer(configData) {
    const container = document.getElementById('config-explorer');
    if (!container) return;
    
    DashboardState.configExplorer = configData;
    renderConfigExplorer(configData);
}

function renderConfigExplorer(config) {
    const container = document.getElementById('config-explorer');
    if (!container) return;
    
    container.innerHTML = `
        <div class="config-explorer">
            <div class="config-search">
                <input type="text" id="config-search-input" placeholder="🔍 Search configuration..." 
                       onkeyup="searchConfig(this.value)">
                <button onclick="expandAllConfig()">Expand All</button>
                <button onclick="collapseAllConfig()">Collapse All</button>
            </div>
            <div class="config-tree" id="config-tree">
                ${renderConfigTree(config)}
            </div>
        </div>
    `;
}

function renderConfigTree(obj, path = '', level = 0) {
    if (!obj || typeof obj !== 'object') {
        return `<span class="config-value">${JSON.stringify(obj)}</span>`;
    }
    
    let html = '<div class="config-node" style="margin-left: ' + (level * 20) + 'px;">';
    
    Object.keys(obj).forEach(key => {
        const value = obj[key];
        const fullPath = path ? `${path}.${key}` : key;
        const isObject = value && typeof value === 'object' && !Array.isArray(value);
        const isArray = Array.isArray(value);
        
        html += `
            <div class="config-item" data-path="${fullPath}">
                <div class="config-key" onclick="toggleConfigNode('${fullPath}')">
                    ${isObject || isArray ? '<span class="toggle-icon">▼</span>' : ''}
                    <span class="key-name">${key}</span>
                    ${isArray ? `<span class="badge">${value.length} items</span>` : ''}
                </div>
                <div class="config-value-container" id="config-${fullPath.replace(/[^a-zA-Z0-9]/g, '_')}">
        `;
        
        if (isObject) {
            html += renderConfigTree(value, fullPath, level + 1);
        } else if (isArray) {
            html += '<div class="config-array">';
            value.forEach((item, idx) => {
                html += `<div class="array-item">[${idx}]: ${JSON.stringify(item)}</div>`;
            });
            html += '</div>';
        } else {
            html += `<span class="config-value">${JSON.stringify(value)}</span>`;
        }
        
        html += '</div></div>';
    });
    
    html += '</div>';
    return html;
}

function toggleConfigNode(path) {
    const node = document.getElementById(`config-${path.replace(/[^a-zA-Z0-9]/g, '_')}`);
    const item = node?.closest('.config-item');
    
    if (node && item) {
        const isOpen = node.style.display !== 'none';
        node.style.display = isOpen ? 'none' : 'block';
        const icon = item.querySelector('.toggle-icon');
        if (icon) icon.textContent = isOpen ? '▶' : '▼';
    }
}

function searchConfig(query) {
    const items = document.querySelectorAll('.config-item');
    const lowerQuery = query.toLowerCase();
    
    items.forEach(item => {
        const text = item.textContent.toLowerCase();
        const matches = text.includes(lowerQuery);
        item.style.display = matches || query === '' ? 'block' : 'none';
        
        if (matches && query !== '') {
            item.classList.add('search-highlight');
        } else {
            item.classList.remove('search-highlight');
        }
    });
}

function expandAllConfig() {
    document.querySelectorAll('.config-value-container').forEach(node => {
        node.style.display = 'block';
    });
    document.querySelectorAll('.toggle-icon').forEach(icon => {
        icon.textContent = '▼';
    });
}

function collapseAllConfig() {
    document.querySelectorAll('.config-value-container').forEach(node => {
        node.style.display = 'none';
    });
    document.querySelectorAll('.toggle-icon').forEach(icon => {
        icon.textContent = '▶';
    });
}

// ============================================================================
// Test & Quality Drill-downs
// ============================================================================

function initQualityDrilldown(qualityData) {
    const container = document.getElementById('quality-drilldown');
    if (!container || !qualityData) return;
    
    renderQualityDrilldown(qualityData);
}

function renderQualityDrilldown(data) {
    const container = document.getElementById('quality-drilldown');
    if (!container) return;
    
    let html = '<div class="quality-grid">';
    
    Object.keys(data).forEach(file => {
        const metrics = data[file];
        const score = metrics.score || 0;
        const statusClass = score >= 80 ? 'success' : score >= 60 ? 'warning' : 'error';
        
        html += `
            <div class="quality-item ${statusClass}" data-file="${file}">
                <div class="quality-header" onclick="toggleQualityDetails('${file}')">
                    <span class="file-name">${file}</span>
                    <span class="quality-score">${score}/100</span>
                    <span class="toggle-icon">▼</span>
                </div>
                <div class="quality-details" id="quality-${file.replace(/[^a-zA-Z0-9]/g, '_')}">
                    <div class="quality-checks">
                        ${renderQualityChecks(metrics)}
                    </div>
                    <button class="btn-view-file" onclick="viewFileDetails('${file}')">View File</button>
                </div>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

function renderQualityChecks(metrics) {
    const checks = [
        { name: 'Error Handling', value: metrics.errorHandling },
        { name: 'Logging', value: metrics.logging },
        { name: 'Test Coverage', value: metrics.testCoverage },
        { name: 'PSScriptAnalyzer', value: metrics.pssa }
    ];
    
    return checks.map(check => `
        <div class="check-item">
            <span class="check-name">${check.name}:</span>
            <span class="check-value">${check.value || 'N/A'}</span>
        </div>
    `).join('');
}

function toggleQualityDetails(file) {
    const details = document.getElementById(`quality-${file.replace(/[^a-zA-Z0-9]/g, '_')}`);
    const item = details?.closest('.quality-item');
    
    if (details && item) {
        const isOpen = details.style.display !== 'none';
        details.style.display = isOpen ? 'none' : 'block';
        item.querySelector('.toggle-icon').textContent = isOpen ? '▶' : '▼';
    }
}

function viewFileDetails(file) {
    createModal(`File Details: ${file}`, `
        <div class="file-details">
            <h4>📊 Metrics</h4>
            <div id="file-metrics"></div>
            <h4>🔍 Issues</h4>
            <div id="file-issues"></div>
            <h4>🧪 Tests</h4>
            <div id="file-tests"></div>
        </div>
    `);
}

// ============================================================================
// GitHub Actions: Issue & PR Creation
// ============================================================================

function createGitHubIssue(template = 'bug') {
    const templates = {
        bug: {
            title: 'Bug Report',
            labels: 'bug',
            body: `**Describe the bug**\nA clear and concise description of what the bug is.\n\n**To Reproduce**\nSteps to reproduce the behavior\n\n**Expected behavior**\nWhat you expected to happen\n\n**Screenshots**\nIf applicable, add screenshots`
        },
        feature: {
            title: 'Feature Request',
            labels: 'enhancement',
            body: `**Is your feature request related to a problem?**\nA clear description of the problem\n\n**Describe the solution**\nWhat you want to happen\n\n**Additional context**\nAny other context`
        },
        docs: {
            title: 'Documentation',
            labels: 'documentation',
            body: `**Documentation issue**\nDescribe what needs to be documented or improved`
        }
    };
    
    const templateData = templates[template] || templates.bug;
    const url = `https://github.com/wizzense/AitherZero/issues/new?` +
                `title=${encodeURIComponent(templateData.title)}&` +
                `labels=${encodeURIComponent(templateData.labels)}&` +
                `body=${encodeURIComponent(templateData.body)}`;
    
    window.open(url, '_blank');
}

function createPullRequest() {
    const url = 'https://github.com/wizzense/AitherZero/compare';
    window.open(url, '_blank');
}

function openDocumentation(section = '') {
    const url = section 
        ? `https://github.com/wizzense/AitherZero/tree/main/docs/${section}`
        : 'https://github.com/wizzense/AitherZero/tree/main/docs';
    window.open(url, '_blank');
}

// ============================================================================
// Release & Build Information
// ============================================================================

function initReleaseTracker(releases) {
    const container = document.getElementById('release-tracker');
    if (!container || !releases) return;
    
    renderReleaseTracker(releases);
}

function renderReleaseTracker(releases) {
    const container = document.getElementById('release-tracker');
    if (!container) return;
    
    let html = '<div class="release-timeline">';
    
    releases.forEach((release, idx) => {
        html += `
            <div class="release-item" data-version="${release.version}">
                <div class="release-marker">${idx === 0 ? '🎯' : '📦'}</div>
                <div class="release-content">
                    <div class="release-header" onclick="toggleRelease('${release.version}')">
                        <h4>${release.version}${idx === 0 ? ' <span class="badge-latest">Latest</span>' : ''}</h4>
                        <span class="release-date">${release.date}</span>
                        <span class="toggle-icon">▼</span>
                    </div>
                    <div class="release-details" id="release-${release.version.replace(/[^a-zA-Z0-9]/g, '_')}">
                        <p>${release.description || 'No description'}</p>
                        <div class="release-assets">
                            ${release.assets ? release.assets.map(asset => 
                                `<a href="${asset.url}" class="asset-link">📥 ${asset.name}</a>`
                            ).join('') : ''}
                        </div>
                        <div class="release-actions">
                            <button onclick="window.open('${release.url}', '_blank')" class="btn-release">View on GitHub</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    });
    
    html += '</div>';
    container.innerHTML = html;
}

function toggleRelease(version) {
    const details = document.getElementById(`release-${version.replace(/[^a-zA-Z0-9]/g, '_')}`);
    const item = details?.closest('.release-item');
    
    if (details && item) {
        const isOpen = details.style.display !== 'none';
        details.style.display = isOpen ? 'none' : 'block';
        item.querySelector('.toggle-icon').textContent = isOpen ? '▶' : '▼';
    }
}

// ============================================================================
// Index File Navigation
// ============================================================================

function initIndexNavigation() {
    const indexContainer = document.getElementById('index-navigation');
    if (!indexContainer) return;
    
    // Discover all index files in the project
    const indices = [
        { path: 'docs/index.md', label: 'Documentation Index' },
        { path: 'automation-scripts/index.md', label: 'Automation Scripts Index' },
        { path: 'domains/index.md', label: 'Domains Index' },
        { path: 'tests/index.md', label: 'Tests Index' },
        { path: 'templates/index.md', label: 'Templates Index' }
    ];
    
    let html = '<div class="index-grid">';
    indices.forEach(index => {
        html += `
            <div class="index-card" onclick="navigateToIndex('${index.path}')">
                <div class="index-icon">📑</div>
                <div class="index-label">${index.label}</div>
            </div>
        `;
    });
    html += '</div>';
    
    indexContainer.innerHTML = html;
}

function navigateToIndex(path) {
    const url = `https://github.com/wizzense/AitherZero/blob/main/${path}`;
    window.open(url, '_blank');
}

// ============================================================================
// Modal System
// ============================================================================

function createModal(title, content) {
    // Remove existing modal if any
    const existingModal = document.getElementById('dashboard-modal');
    if (existingModal) {
        existingModal.remove();
    }
    
    const modal = document.createElement('div');
    modal.id = 'dashboard-modal';
    modal.className = 'modal-overlay';
    modal.innerHTML = `
        <div class="modal-container">
            <div class="modal-header">
                <h3>${title}</h3>
                <button class="modal-close" onclick="closeModal()">×</button>
            </div>
            <div class="modal-body">
                ${content}
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Close on overlay click
    modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();
    });
    
    return modal;
}

function closeModal() {
    const modal = document.getElementById('dashboard-modal');
    if (modal) {
        modal.remove();
    }
}

// ============================================================================
// Initialization
// ============================================================================

document.addEventListener('DOMContentLoaded', function() {
    // Initialize all interactive components
    initBreadcrumbs();
    initIndexNavigation();
    
    // Smooth scroll for all anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });
    
    // Keyboard shortcuts
    document.addEventListener('keydown', function(e) {
        // Ctrl/Cmd + K: Toggle TOC
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            toggleToc();
        }
        // Escape: Close modals and menus
        if (e.key === 'Escape') {
            closeModal();
            document.getElementById('toc')?.classList.remove('open');
        }
        // Ctrl/Cmd + /: Focus search
        if ((e.ctrlKey || e.metaKey) && e.key === '/') {
            e.preventDefault();
            document.getElementById('config-search-input')?.focus();
        }
    });
    
    // Scroll event handlers
    window.addEventListener('scroll', highlightToc);
    highlightToc();
    
    // Copy to clipboard for code blocks
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
    
    // Interactive card effects
    document.querySelectorAll('.metric-card').forEach(card => {
        card.addEventListener('click', function(e) {
            if (e.target.tagName === 'A' || e.target.closest('a') || e.target.tagName === 'BUTTON') {
                return;
            }
            this.style.transform = 'scale(0.98)';
            setTimeout(() => {
                this.style.transform = '';
            }, 150);
        });
    });
    
    console.log('🚀 AitherZero Interactive Dashboard Initialized');
    console.log('📋 Keyboard Shortcuts:');
    console.log('  • Ctrl/Cmd + K: Toggle navigation');
    console.log('  • Ctrl/Cmd + /: Focus search');
    console.log('  • Escape: Close modals/menus');
    console.log('  • Click code blocks to copy');
});

// Update timestamp
function updateTimestamp() {
    const now = new Date();
    const timeString = now.toLocaleString();
    document.title = 'AitherZero Dashboard - Updated ' + timeString;
}
setInterval(updateTimestamp, 60000);
