// Healthcare Practice - Main JavaScript

const API_BASE = '';

// Auth state management
const Auth = {
    getToken() {
        return localStorage.getItem('patient_token');
    },
    getAdminToken() {
        return localStorage.getItem('admin_token');
    },
    getPatient() {
        const data = localStorage.getItem('patient_data');
        return data ? JSON.parse(data) : null;
    },
    getAdmin() {
        const data = localStorage.getItem('admin_data');
        return data ? JSON.parse(data) : null;
    },
    setPatient(token, patient) {
        localStorage.setItem('patient_token', token);
        localStorage.setItem('patient_data', JSON.stringify(patient));
    },
    setAdmin(token, admin) {
        localStorage.setItem('admin_token', token);
        localStorage.setItem('admin_data', JSON.stringify(admin));
    },
    logout() {
        localStorage.removeItem('patient_token');
        localStorage.removeItem('patient_data');
        window.location.href = '/';
    },
    adminLogout() {
        localStorage.removeItem('admin_token');
        localStorage.removeItem('admin_data');
        window.location.href = '/';
    },
    isLoggedIn() {
        return !!this.getToken();
    },
    isAdminLoggedIn() {
        return !!this.getAdminToken();
    }
};

// API helper
async function api(endpoint, options = {}) {
    const config = {
        headers: {
            'Content-Type': 'application/json',
            ...options.headers
        },
        ...options
    };

    // Add auth token if available
    const token = options.adminAuth ? Auth.getAdminToken() : Auth.getToken();
    if (token) {
        config.headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${API_BASE}${endpoint}`, config);
    const data = await response.json();

    if (!response.ok) {
        throw new Error(data.error || 'Request failed');
    }

    return data;
}

// Mobile menu toggle
function initMobileMenu() {
    const btn = document.querySelector('.mobile-menu-btn');
    const links = document.querySelector('.nav-links');
    if (btn && links) {
        btn.addEventListener('click', () => {
            links.classList.toggle('open');
        });
    }
}

// Update nav based on auth state
function updateNav() {
    const navActions = document.querySelector('.nav-actions');
    if (!navActions) return;

    if (Auth.isLoggedIn()) {
        const patient = Auth.getPatient();
        navActions.innerHTML = `
            <a href="/portal" class="btn btn-outline btn-sm">My Portal</a>
            <button onclick="Auth.logout()" class="btn btn-sm" style="background:#EF4444;color:#fff">Logout</button>
        `;
    } else {
        navActions.innerHTML = `
            <a href="/portal" class="btn btn-outline btn-sm">Patient Login</a>
            <a href="/book" class="btn btn-primary btn-sm">Book Now</a>
        `;
    }
}

// Tab functionality
function initTabs() {
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            const tabGroup = tab.closest('.tabs-container') || tab.parentElement.parentElement;
            tabGroup.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            tabGroup.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            tab.classList.add('active');
            const target = document.getElementById(tab.dataset.tab);
            if (target) target.classList.add('active');
        });
    });
}

// Show alert message
function showAlert(container, message, type = 'success') {
    const alert = document.createElement('div');
    alert.className = `alert alert-${type}`;
    alert.textContent = message;
    container.prepend(alert);
    setTimeout(() => alert.remove(), 5000);
}

// Format currency
function formatCurrency(cents) {
    return `$${(cents / 100).toFixed(2)}`;
}

// Format date
function formatDate(dateStr) {
    const date = new Date(dateStr + 'T00:00:00');
    return date.toLocaleDateString('en-US', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' });
}

// Format time
function formatTime(timeStr) {
    const [hours, minutes] = timeStr.split(':');
    const h = parseInt(hours);
    const ampm = h >= 12 ? 'PM' : 'AM';
    const h12 = h % 12 || 12;
    return `${h12}:${minutes} ${ampm}`;
}

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
    initMobileMenu();
    updateNav();
    initTabs();
});
