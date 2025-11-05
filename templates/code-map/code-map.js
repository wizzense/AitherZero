// Application state
let currentTab = 'domains';
let currentView = 'tree';
let selectedItem = null;

// Initialize application
document.addEventListener('DOMContentLoaded', function() {
    initializeTabs();
    initializeToolbar();
    renderContent();
    renderVisualization();
});

// Tab switching
function initializeTabs() {
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', function() {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            this.classList.add('active');
            currentTab = this.dataset.tab;
            renderContent();
        });
    });
}

// Toolbar button handling
function initializeToolbar() {
    document.getElementById('btn-tree').addEventListener('click', () => switchView('tree'));
    document.getElementById('btn-graph').addEventListener('click', () => switchView('graph'));
    document.getElementById('btn-matrix').addEventListener('click', () => switchView('matrix'));
    document.getElementById('btn-sunburst').addEventListener('click', () => switchView('sunburst'));
    document.getElementById('btn-export').addEventListener('click', exportData);
    document.getElementById('btn-back').addEventListener('click', () => {
        window.location.href = 'dashboard.html';
    });
    
    // Search
    document.getElementById('search-input').addEventListener('input', function(e) {
        filterContent(e.target.value);
    });
}

function switchView(view) {
    currentView = view;
    document.querySelectorAll('#toolbar .btn').forEach(btn => btn.classList.remove('active'));
    document.getElementById('btn-' + view).classList.add('active');
    renderVisualization();
}

// Render sidebar content
function renderContent() {
    const contentArea = document.getElementById('content-area');
    
    switch(currentTab) {
        case 'domains':
            renderDomains(contentArea);
            break;
        case 'functions':
            renderFunctions(contentArea);
            break;
        case 'files':
            renderFiles(contentArea);
            break;
        case 'stats':
            renderStats(contentArea);
            break;
    }
}

function renderDomains(container) {
    let html = '';
    const domains = Object.keys(codeMapData.domains).sort();
    
    domains.forEach(domainName => {
        const domain = codeMapData.domains[domainName];
        html += '<div class="tree-item" onclick="selectDomain(\'' + domainName + '\')">';
        html += '<span class="tree-icon">📦</span>';
        html += '<span class="tree-label">' + domainName + '</span>';
        html += '<span class="tree-badge">' + domain.Modules.length + '</span>';
        html += '</div>';
    });
    
    container.innerHTML = html;
}

function renderFunctions(container) {
    let html = '';
    codeMapData.functions.slice(0, 100).forEach(func => {
        const usageCount = codeMapData.functionUsage[func.Name] ? codeMapData.functionUsage[func.Name].length : 0;
        html += '<div class="tree-item" onclick="selectFunction(\'' + func.Name + '\')">';
        html += '<span class="tree-icon">⚡</span>';
        html += '<span class="tree-label">' + func.Name + '</span>';
        html += '<span class="tree-badge">' + usageCount + '</span>';
        html += '</div>';
    });
    
    if (codeMapData.functions.length > 100) {
        html += '<div style="padding: 10px; text-align: center; color: var(--text-secondary);">';
        html += 'Showing 100 of ' + codeMapData.functions.length + ' functions';
        html += '</div>';
    }
    
    container.innerHTML = html;
}

function renderFiles(container) {
    let html = '';
    const allFiles = codeMapData.files.Scripts.concat(codeMapData.files.Modules);
    
    allFiles.slice(0, 100).forEach(file => {
        const icon = file.Type === 'Module' ? '📘' : '📄';
        html += '<div class="tree-item" onclick="selectFile(\'' + file.Path.replace(/'/g, "\\'") + '\')">';
        html += '<span class="tree-icon">' + icon + '</span>';
        html += '<span class="tree-label">' + file.Name + '</span>';
        html += '</div>';
    });
    
    container.innerHTML = html;
}

function renderStats(container) {
    let html = '<div class="stat-grid">';
    html += '<div class="stat-card">';
    html += '<div class="stat-value">' + codeMapData.stats.totalFiles + '</div>';
    html += '<div class="stat-label">Total Files</div>';
    html += '</div>';
    html += '<div class="stat-card">';
    html += '<div class="stat-value">' + codeMapData.stats.totalFunctions + '</div>';
    html += '<div class="stat-label">Functions</div>';
    html += '</div>';
    html += '<div class="stat-card">';
    html += '<div class="stat-value">' + codeMapData.stats.totalDomains + '</div>';
    html += '<div class="stat-label">Domains</div>';
    html += '</div>';
    html += '<div class="stat-card">';
    html += '<div class="stat-value">' + codeMapData.stats.totalUsageEdges + '</div>';
    html += '<div class="stat-label">Usage Links</div>';
    html += '</div>';
    html += '</div>';
    html += '<div style="margin-top: 20px; padding: 15px; background: var(--bg-dark); border-radius: 8px;">';
    html += '<h4 style="color: var(--text-primary); margin-bottom: 10px;">Top Domains</h4>';
    html += '<div id="top-domains"></div>';
    html += '</div>';
    
    container.innerHTML = html;
    
    // Add top domains
    const domains = Object.keys(codeMapData.domains).sort((a, b) => 
        codeMapData.domains[b].Functions.length - codeMapData.domains[a].Functions.length
    );
    
    let domainsHTML = '';
    domains.slice(0, 5).forEach(domain => {
        const funcCount = codeMapData.domains[domain].Functions.length;
        domainsHTML += '<div style="padding: 8px; margin: 5px 0; background: var(--card-bg); border-radius: 4px;">';
        domainsHTML += '<strong>' + domain + '</strong>: ' + funcCount + ' functions';
        domainsHTML += '</div>';
    });
    
    document.getElementById('top-domains').innerHTML = domainsHTML;
}

// Visualization rendering
function renderVisualization() {
    const container = document.getElementById('graph-container');
    container.innerHTML = '';
    
    switch(currentView) {
        case 'tree':
            renderTreeView(container);
            break;
        case 'graph':
            renderGraphView(container);
            break;
        case 'matrix':
            renderMatrixView(container);
            break;
        case 'sunburst':
            renderSunburstView(container);
            break;
    }
}

function renderTreeView(container) {
    // Simple tree visualization
    const width = container.clientWidth;
    const height = container.clientHeight;
    
    const svg = d3.select(container)
        .append('svg')
        .attr('width', width)
        .attr('height', height);
    
    // Build hierarchy
    const rootData = {
        name: 'AitherZero',
        children: Object.keys(codeMapData.domains).map(domainName => ({
            name: domainName,
            children: codeMapData.domains[domainName].Modules.map(m => ({
                name: m.Name,
                path: m.Path
            }))
        }))
    };
    
    const root = d3.hierarchy(rootData);
    const treeLayout = d3.tree().size([height - 40, width - 200]);
    treeLayout(root);
    
    // Draw links
    svg.selectAll('.link')
        .data(root.links())
        .enter()
        .append('path')
        .attr('class', 'link')
        .attr('d', d3.linkHorizontal()
            .x(d => d.y + 100)
            .y(d => d.x + 20));
    
    // Draw nodes
    const node = svg.selectAll('.node')
        .data(root.descendants())
        .enter()
        .append('g')
        .attr('class', 'node')
        .attr('transform', d => 'translate(' + (d.y + 100) + ',' + (d.x + 20) + ')')
        .on('click', function(event, d) {
            showInfoPanel(d.data);
        });
    
    node.append('circle')
        .attr('r', 5);
    
    node.append('text')
        .attr('dx', 8)
        .attr('dy', 4)
        .text(d => d.data.name);
}

function renderGraphView(container) {
    container.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary);"><h2>🕸️ Graph View - Force-directed layout</h2></div>';
}

function renderMatrixView(container) {
    container.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary);"><h2>📊 Matrix View - Dependency matrix</h2></div>';
}

function renderSunburstView(container) {
    container.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary);"><h2>☀️ Sunburst View - Hierarchical visualization</h2></div>';
}

// Selection handling
function selectDomain(domainName) {
    selectedItem = { type: 'domain', data: codeMapData.domains[domainName], name: domainName };
    showInfoPanel(selectedItem);
}

function selectFunction(functionName) {
    const func = codeMapData.functions.find(f => f.Name === functionName);
    selectedItem = { type: 'function', data: func, name: functionName };
    showInfoPanel(selectedItem);
}

function selectFile(filePath) {
    selectedItem = { type: 'file', data: filePath };
    showInfoPanel(selectedItem);
}

function showInfoPanel(item) {
    const panel = document.getElementById('info-panel');
    const content = document.getElementById('info-content');
    
    let html = '';
    
    if (item.type === 'domain') {
        const modulesHTML = item.data.Modules.map(m => '<li>' + m.Name + '</li>').join('');
        const functionsHTML = item.data.Functions.slice(0, 10).map(f => '<li>' + f.Name + '</li>').join('');
        
        html = '<h3>📦 ' + item.name + '</h3>';
        html += '<div class="info-section">';
        html += '<h4>Modules (' + item.data.Modules.length + ')</h4>';
        html += '<ul class="info-list">' + modulesHTML + '</ul>';
        html += '</div>';
        html += '<div class="info-section">';
        html += '<h4>Functions (' + item.data.Functions.length + ')</h4>';
        html += '<ul class="info-list">' + functionsHTML + '</ul>';
        html += '</div>';
    } else if (item.type === 'function') {
        const usage = codeMapData.functionUsage[item.name] || [];
        const usageHTML = usage.slice(0, 10).map(u => '<li>' + u + '</li>').join('');
        
        html = '<h3>⚡ ' + item.name + '</h3>';
        html += '<div class="info-section">';
        html += '<h4>Defined In</h4>';
        html += '<p>' + item.data.File + ' (Line ' + item.data.Line + ')</p>';
        html += '</div>';
        if (item.data.Synopsis) {
            html += '<div class="info-section">';
            html += '<h4>Synopsis</h4>';
            html += '<p>' + item.data.Synopsis + '</p>';
            html += '</div>';
        }
        html += '<div class="info-section">';
        html += '<h4>Used In (' + usage.length + ' files)</h4>';
        html += '<ul class="info-list">' + usageHTML + '</ul>';
        html += '</div>';
    } else if (item.name) {
        html = '<h3>' + item.name + '</h3><p>Click on a node to see details</p>';
    }
    
    content.innerHTML = html;
    panel.classList.add('show');
}

function closeInfoPanel() {
    document.getElementById('info-panel').classList.remove('show');
}

function filterContent(query) {
    // Implement search filtering
    console.log('Searching for:', query);
}

function exportData() {
    const dataStr = JSON.stringify(codeMapData, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'aitherzero-codemap.json';
    link.click();
}
