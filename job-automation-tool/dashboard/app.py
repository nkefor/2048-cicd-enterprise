"""
Flask web dashboard for job automation metrics and monitoring.

Provides real-time visualization of job applications, success rates, and platform health.
Access at http://localhost:5000
"""

from flask import Flask, render_template, jsonify, request
from datetime import datetime
import os
from pathlib import Path

from dashboard.metrics_tracker import MetricsTracker
from utils.logger import setup_logger, log_info

# Initialize Flask app
app = Flask(
    __name__,
    template_folder='dashboard/templates',
    static_folder='dashboard/static'
)

# Configure app
app.config['JSON_SORT_KEYS'] = False

# Initialize metrics tracker
metrics = MetricsTracker()

# Setup logger
logger = setup_logger('Dashboard')


# Routes

@app.route('/')
def index():
    """Dashboard homepage."""
    return render_template('index.html')


@app.route('/api/stats')
def api_stats():
    """Get current statistics."""
    try:
        stats = metrics.get_statistics()
        return jsonify({
            'success': True,
            'data': stats
        })
    except Exception as e:
        log_info(f"Error getting stats: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/applications')
def api_applications():
    """Get recent applications."""
    try:
        limit = 50
        apps = metrics.get_recent_applications(limit=limit)

        return jsonify({
            'success': True,
            'data': apps,
            'count': len(apps)
        })
    except Exception as e:
        log_info(f"Error getting applications: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/platforms')
def api_platforms():
    """Get platform health status."""
    try:
        health = metrics.get_platform_health()

        # Format for API
        platforms = []
        for platform, data in health.items():
            platforms.append({
                'name': platform,
                'overall_success_rate': round(data['overall_success_rate'], 1),
                'recent_success_rate': round(data['recent_success_rate'], 1),
                'total_applications': data['total_applications'],
                'total_successes': data['total_successes'],
                'status': data['status'],
                'last_run': data['last_run']
            })

        return jsonify({
            'success': True,
            'data': platforms
        })
    except Exception as e:
        log_info(f"Error getting platform health: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/chart-data')
def api_chart_data():
    """Get chart data for applications over time."""
    try:
        chart_data = metrics.get_chart_data(days=7)

        return jsonify({
            'success': True,
            'data': chart_data
        })
    except Exception as e:
        log_info(f"Error getting chart data: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/api/health')
def api_health():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'metrics_loaded': True
    })


@app.route('/api/export')
def api_export():
    """Export all metrics as JSON."""
    try:
        export_dir = Path('data/exports')
        export_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        export_file = export_dir / f"metrics_{timestamp}.json"

        if metrics.export_json(str(export_file)):
            return jsonify({
                'success': True,
                'file': str(export_file)
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Export failed'
            }), 500

    except Exception as e:
        log_info(f"Error exporting metrics: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


# Error handlers

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500


# Before request hooks

@app.before_request
def before_request():
    """Log incoming requests."""
    if not request.path.startswith('/static'):
        log_info(f"[DASHBOARD] {request.method} {request.path}")


# Context processors

@app.context_processor
def inject_now():
    """Inject current time into templates."""
    return {'now': datetime.now()}


def create_app():
    """Create and configure Flask app."""
    return app


if __name__ == '__main__':
    print("=" * 80)
    print("  JOB AUTOMATION DASHBOARD")
    print("  Starting Flask web server...")
    print("=" * 80)
    print("")
    print("Dashboard available at: http://localhost:5000")
    print("")
    print("Press Ctrl+C to stop the server")
    print("")

    # Ensure data directory exists
    Path('data/metrics').mkdir(parents=True, exist_ok=True)
    Path('data/exports').mkdir(parents=True, exist_ok=True)

    # Run Flask app
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,  # Set to False for production
        use_reloader=True
    )
