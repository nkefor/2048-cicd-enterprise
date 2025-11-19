/**
 * Job Automation Dashboard - Frontend JavaScript
 *
 * Handles real-time updates, charts, and API communication
 */

// Global chart instances
let chartApplications = null;
let chartPlatforms = null;

/**
 * Initialize dashboard on page load
 */
function initializeDashboard() {
    console.log('[Dashboard] Initializing...');

    // Load initial data
    loadStatistics();
    loadApplications();
    loadPlatforms();
    loadChartData();

    // Update timestamp
    updateTimestamp();
}

/**
 * Refresh all dashboard data
 */
function refreshDashboard() {
    console.log('[Dashboard] Refreshing...');

    loadStatistics();
    loadApplications();
    loadPlatforms();
    loadChartData();

    updateTimestamp();
}

/**
 * Load and display statistics
 */
function loadStatistics() {
    fetch('/api/stats')
        .then(response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            return response.json();
        })
        .then(data => {
            if (!data.success) {
                console.error('[Dashboard] Stats error:', data.error);
                return;
            }

            const stats = data.data;

            // Update cards
            document.getElementById('total-apps').textContent = stats.total_applications;
            document.getElementById('successful-apps').textContent = stats.successful_applications;
            document.getElementById('failed-apps').textContent = stats.failed_applications;

            // Format success rate
            const successRate = stats.overall_success_rate.toFixed(1);
            document.getElementById('success-rate').textContent = `Success Rate: ${successRate}%`;

            // Today stats
            if (stats.today) {
                document.getElementById('today-apps').textContent = `Today: ${stats.today.total}`;
            }

            // This week
            if (stats.this_week) {
                document.getElementById('this-week').textContent = `This week: ${stats.this_week.total}`;
            }

            console.log('[Dashboard] Stats loaded:', stats);
        })
        .catch(error => {
            console.error('[Dashboard] Failed to load stats:', error);
        });
}

/**
 * Load and display recent applications
 */
function loadApplications() {
    fetch('/api/applications')
        .then(response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            return response.json();
        })
        .then(data => {
            if (!data.success) {
                console.error('[Dashboard] Applications error:', data.error);
                return;
            }

            const applications = data.data;
            const tbody = document.getElementById('applications-table');

            if (applications.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="text-center text-muted">No applications yet</td></tr>';
                return;
            }

            // Build table rows
            tbody.innerHTML = applications.reverse().map(app => {
                const timestamp = new Date(app.timestamp);
                const dateStr = timestamp.toLocaleDateString();
                const timeStr = timestamp.toLocaleTimeString();

                const statusBadge = app.success
                    ? '<span class="badge bg-success"><i class="fas fa-check"></i> Success</span>'
                    : '<span class="badge bg-danger"><i class="fas fa-times"></i> Failed</span>';

                const platformBadge = `<span class="badge bg-info">${app.platform}</span>`;

                return `
                    <tr class="${app.success ? '' : 'table-danger'}">
                        <td class="text-muted small">${dateStr} ${timeStr}</td>
                        <td>${platformBadge}</td>
                        <td><strong>${escapeHtml(app.job_title)}</strong></td>
                        <td>${escapeHtml(app.company)}</td>
                        <td>${statusBadge}</td>
                    </tr>
                `;
            }).join('');

            console.log('[Dashboard] Loaded', applications.length, 'applications');
        })
        .catch(error => {
            console.error('[Dashboard] Failed to load applications:', error);
        });
}

/**
 * Load and display platform health
 */
function loadPlatforms() {
    fetch('/api/platforms')
        .then(response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            return response.json();
        })
        .then(data => {
            if (!data.success) {
                console.error('[Dashboard] Platforms error:', data.error);
                return;
            }

            const platforms = data.data;
            const tbody = document.getElementById('platforms-table');

            // Update active platforms count
            document.getElementById('active-platforms').textContent = platforms.length;

            if (platforms.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No platform data available</td></tr>';
                return;
            }

            // Build table rows
            tbody.innerHTML = platforms.map(platform => {
                const statusIcon = getStatusIcon(platform.status);
                const overallRate = platform.overall_success_rate.toFixed(1);
                const recentRate = platform.recent_success_rate.toFixed(1);

                const lastRun = platform.last_run
                    ? new Date(platform.last_run).toLocaleString()
                    : 'Never';

                return `
                    <tr>
                        <td><strong>${platform.name.toUpperCase()}</strong></td>
                        <td>
                            <div class="progress" style="height: 20px;">
                                <div class="progress-bar bg-success" style="width: ${overallRate}%">
                                    ${overallRate}%
                                </div>
                            </div>
                        </td>
                        <td>
                            <div class="progress" style="height: 20px;">
                                <div class="progress-bar bg-info" style="width: ${recentRate}%">
                                    ${recentRate}%
                                </div>
                            </div>
                        </td>
                        <td>${platform.total_applications}</td>
                        <td>${statusIcon}</td>
                        <td class="text-muted small">${lastRun}</td>
                    </tr>
                `;
            }).join('');

            console.log('[Dashboard] Loaded', platforms.length, 'platforms');
        })
        .catch(error => {
            console.error('[Dashboard] Failed to load platforms:', error);
        });
}

/**
 * Load and display chart data
 */
function loadChartData() {
    fetch('/api/chart-data')
        .then(response => {
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            return response.json();
        })
        .then(data => {
            if (!data.success) {
                console.error('[Dashboard] Chart data error:', data.error);
                return;
            }

            const chartData = data.data;

            // Update applications chart
            updateApplicationsChart(chartData);

            // Update platforms chart (from stats)
            fetch('/api/stats')
                .then(r => r.json())
                .then(d => {
                    if (d.success) {
                        updatePlatformsChart(d.data.by_platform);
                    }
                })
                .catch(e => console.error('Failed to load platform stats:', e));

            console.log('[Dashboard] Chart data loaded');
        })
        .catch(error => {
            console.error('[Dashboard] Failed to load chart data:', error);
        });
}

/**
 * Update applications over time chart
 */
function updateApplicationsChart(data) {
    const ctx = document.getElementById('chartApplications');
    if (!ctx) return;

    const chartConfig = {
        type: 'line',
        data: {
            labels: data.dates,
            datasets: [
                {
                    label: 'Total Applications',
                    data: data.totals,
                    borderColor: '#007bff',
                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                    tension: 0.4,
                    fill: true,
                    borderWidth: 2
                },
                {
                    label: 'Successful',
                    data: data.successes,
                    borderColor: '#28a745',
                    backgroundColor: 'rgba(40, 167, 69, 0.1)',
                    tension: 0.4,
                    fill: true,
                    borderWidth: 2
                },
                {
                    label: 'Failed',
                    data: data.failures,
                    borderColor: '#dc3545',
                    backgroundColor: 'rgba(220, 53, 69, 0.1)',
                    tension: 0.4,
                    fill: true,
                    borderWidth: 2
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Number of Applications'
                    }
                }
            }
        }
    };

    if (chartApplications) {
        chartApplications.data = chartConfig.data;
        chartApplications.options = chartConfig.options;
        chartApplications.update();
    } else {
        chartApplications = new Chart(ctx, chartConfig);
    }
}

/**
 * Update platform success rates chart
 */
function updatePlatformsChart(byPlatform) {
    const ctx = document.getElementById('chartPlatforms');
    if (!ctx) return;

    const platforms = Object.keys(byPlatform);
    const rates = platforms.map(p => byPlatform[p].success_rate.toFixed(1));

    const colors = [
        '#007bff', '#28a745', '#ffc107', '#dc3545', '#17a2b8',
        '#fd7e14', '#6f42c1', '#e83e8c', '#20c997', '#6c757d'
    ];

    const chartConfig = {
        type: 'doughnut',
        data: {
            labels: platforms.map(p => p.toUpperCase()),
            datasets: [
                {
                    data: rates,
                    backgroundColor: colors.slice(0, platforms.length),
                    borderColor: '#fff',
                    borderWidth: 2
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'bottom'
                },
                title: {
                    display: false
                }
            }
        }
    };

    if (chartPlatforms) {
        chartPlatforms.data = chartConfig.data;
        chartPlatforms.options = chartConfig.options;
        chartPlatforms.update();
    } else {
        chartPlatforms = new Chart(ctx, chartConfig);
    }
}

/**
 * Get status icon and badge
 */
function getStatusIcon(status) {
    switch (status) {
        case 'healthy':
            return '<span class="badge bg-success"><i class="fas fa-check-circle"></i> Healthy</span>';
        case 'degraded':
            return '<span class="badge bg-warning"><i class="fas fa-exclamation-triangle"></i> Degraded</span>';
        case 'unhealthy':
            return '<span class="badge bg-danger"><i class="fas fa-times-circle"></i> Unhealthy</span>';
        default:
            return '<span class="badge bg-secondary">Unknown</span>';
    }
}

/**
 * Update last update timestamp
 */
function updateTimestamp() {
    const now = new Date();
    const timeStr = now.toLocaleTimeString();
    const dateStr = now.toLocaleDateString();

    document.getElementById('last-update').textContent = `Last update: ${timeStr}`;
    document.getElementById('footer-time').textContent = `${dateStr} ${timeStr}`;
}

/**
 * Escape HTML special characters
 */
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Format date nicely
 */
function formatDate(date) {
    return new Date(date).toLocaleDateString();
}

/**
 * Format time nicely
 */
function formatTime(date) {
    return new Date(date).toLocaleTimeString();
}

/**
 * Format datetime nicely
 */
function formatDateTime(date) {
    const d = new Date(date);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString();
}
