/**
 * Enhanced Charts Module for AitherZero Dashboard
 * Provides interactive visualizations using Chart.js
 */

// ============================================================================
// Quality Trends Chart
// ============================================================================
function renderQualityTrendsChart(canvasId, trendsData) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    // Extract data from trends
    const labels = trendsData.map(d => d.Timestamp || d.Date).slice(-10);
    const scores = trendsData.map(d => d.Score || d.AverageScore).slice(-10);

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Quality Score',
                data: scores,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                tension: 0.4,
                fill: true,
                pointRadius: 4,
                pointHoverRadius: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    labels: { color: '#c9d1d9' }
                },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    backgroundColor: 'rgba(22, 27, 34, 0.9)',
                    titleColor: '#c9d1d9',
                    bodyColor: '#8b949e',
                    borderColor: '#30363d',
                    borderWidth: 1
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100,
                    ticks: { color: '#8b949e' },
                    grid: { color: 'rgba(48, 54, 61, 0.3)' }
                },
                x: {
                    ticks: { color: '#8b949e' },
                    grid: { color: 'rgba(48, 54, 61, 0.3)' }
                }
            }
        }
    });
}

// ============================================================================
// Test Pass Rate Chart
// ============================================================================
function renderTestPassRateChart(canvasId, testData) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Passed', 'Failed', 'Skipped'],
            datasets: [{
                data: [
                    testData.Passed || 0,
                    testData.Failed || 0,
                    testData.Skipped || 0
                ],
                backgroundColor: [
                    '#238636',
                    '#da3633',
                    '#d29922'
                ],
                borderColor: '#161b22',
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#c9d1d9', padding: 15 }
                },
                tooltip: {
                    backgroundColor: 'rgba(22, 27, 34, 0.9)',
                    titleColor: '#c9d1d9',
                    bodyColor: '#8b949e',
                    borderColor: '#30363d',
                    borderWidth: 1
                }
            }
        }
    });
}

// ============================================================================
// Coverage Breakdown Chart
// ============================================================================
function renderCoverageChart(canvasId, coverageData) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    const totalLines = coverageData.TotalLines || 1;
    const coveredLines = coverageData.CoveredLines || 0;
    const uncoveredLines = totalLines - coveredLines;

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Line Coverage'],
            datasets: [{
                label: 'Covered',
                data: [coveredLines],
                backgroundColor: '#238636'
            }, {
                label: 'Uncovered',
                data: [uncoveredLines],
                backgroundColor: '#da3633'
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    labels: { color: '#c9d1d9' }
                },
                tooltip: {
                    backgroundColor: 'rgba(22, 27, 34, 0.9)',
                    titleColor: '#c9d1d9',
                    bodyColor: '#8b949e',
                    borderColor: '#30363d',
                    borderWidth: 1,
                    callbacks: {
                        label: function(context) {
                            const value = context.parsed.x;
                            const total = coveredLines + uncoveredLines;
                            const percentage = ((value / total) * 100).toFixed(1);
                            return `${context.dataset.label}: ${value} lines (${percentage}%)`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    stacked: true,
                    ticks: { color: '#8b949e' },
                    grid: { color: 'rgba(48, 54, 61, 0.3)' }
                },
                y: {
                    stacked: true,
                    ticks: { color: '#8b949e' },
                    grid: { display: false }
                }
            }
        }
    });
}

// ============================================================================
// PSScriptAnalyzer Issues by Severity
// ============================================================================
function renderPSSAIssuesChart(canvasId, pssaData) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Errors', 'Warnings', 'Information'],
            datasets: [{
                label: 'Issues',
                data: [
                    pssaData.Errors || 0,
                    pssaData.Warnings || 0,
                    pssaData.Information || 0
                ],
                backgroundColor: [
                    '#da3633',
                    '#d29922',
                    '#1f6feb'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(22, 27, 34, 0.9)',
                    titleColor: '#c9d1d9',
                    bodyColor: '#8b949e',
                    borderColor: '#30363d',
                    borderWidth: 1
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: { color: '#8b949e' },
                    grid: { color: 'rgba(48, 54, 61, 0.3)' }
                },
                x: {
                    ticks: { color: '#8b949e' },
                    grid: { display: false }
                }
            }
        }
    });
}

// ============================================================================
// File Quality Heatmap
// ============================================================================
function renderFileQualityHeatmap(containerId, fileMetricsData) {
    const container = document.getElementById(containerId);
    if (!container || !fileMetricsData || fileMetricsData.length === 0) {
        if (container) {
            container.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 40px;">No file metrics available. Run quality validation to see data.</p>';
        }
        return;
    }

    // Sort by score (lowest first - these need attention)
    const sortedFiles = fileMetricsData.slice().sort((a, b) => a.Score - b.Score).slice(0, 50);

    const heatmapHTML = sortedFiles.map(file => {
        const scoreColor = file.Score >= 90 ? '#238636' :
                          file.Score >= 70 ? '#d29922' :
                          file.Score >= 50 ? '#f85149' : '#da3633';
        
        const fileName = file.Path.split('/').pop();
        const fileDir = file.Path.substring(0, file.Path.lastIndexOf('/'));
        
        return `
            <div class="heatmap-cell" 
                 style="background: linear-gradient(90deg, ${scoreColor} ${file.Score}%, rgba(22, 27, 34, 0.3) ${file.Score}%)"
                 onclick="showFileDetails('${file.Path}')"
                 title="${file.Path}: ${file.Score}/100">
                <div class="heatmap-cell-label">
                    <span class="file-name">${fileName}</span>
                    <span class="file-score">${file.Score}</span>
                </div>
                <div class="heatmap-cell-path">${fileDir}</div>
            </div>
        `;
    }).join('');

    container.innerHTML = `
        <div class="heatmap-grid">
            ${heatmapHTML}
        </div>
        <style>
            .heatmap-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
                gap: 10px;
                padding: 10px;
            }
            .heatmap-cell {
                padding: 12px;
                border-radius: 6px;
                cursor: pointer;
                transition: all 0.2s;
                border: 1px solid var(--card-border);
                min-height: 60px;
                display: flex;
                flex-direction: column;
                justify-content: center;
            }
            .heatmap-cell:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
                border-color: var(--primary);
            }
            .heatmap-cell-label {
                display: flex;
                justify-content: space-between;
                align-items: center;
                font-weight: bold;
                color: var(--text-primary);
            }
            .file-name {
                font-size: 0.9rem;
                flex: 1;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }
            .file-score {
                font-size: 1.1rem;
                margin-left: 10px;
            }
            .heatmap-cell-path {
                font-size: 0.75rem;
                color: var(--text-secondary);
                margin-top: 4px;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }
        </style>
    `;
}

// ============================================================================
// Initialize all charts
// ============================================================================
function initializeAllCharts(dashboardData) {
    // Quality trends
    if (dashboardData.QualityTrends && dashboardData.QualityTrends.ScoreHistory) {
        renderQualityTrendsChart('qualityTrendsChart', dashboardData.QualityTrends.ScoreHistory);
    }

    // Test results
    if (dashboardData.Tests) {
        renderTestPassRateChart('testPassRateChart', dashboardData.Tests);
    }

    // Coverage
    if (dashboardData.Coverage) {
        renderCoverageChart('coverageChart', dashboardData.Coverage);
    }

    // PSSA Issues
    if (dashboardData.PSScriptAnalyzer) {
        renderPSSAIssuesChart('pssaIssuesChart', dashboardData.PSScriptAnalyzer);
    }

    // File quality heatmap
    if (dashboardData.FileMetrics) {
        renderFileQualityHeatmap('fileQualityHeatmap', dashboardData.FileMetrics);
    }
}

// Export for use in dashboard
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        renderQualityTrendsChart,
        renderTestPassRateChart,
        renderCoverageChart,
        renderPSSAIssuesChart,
        renderFileQualityHeatmap,
        initializeAllCharts
    };
}
