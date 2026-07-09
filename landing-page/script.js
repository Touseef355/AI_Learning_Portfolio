const API_BASE = window.API_BASE || 'http://127.0.0.1:8000';
const DASHBOARD_BASE = window.DASHBOARD_BASE || 'http://localhost:5173';

// ════════════════════════════════════════════
// WAIT FOR DOM TO LOAD
// ════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function () {
    console.log('DOM fully loaded');
    initializeNavigation();
    initializeModal();
    initializeSlider();
    initializeRealTimeValidation();
    initializeHeroSlider();
});

// ════════════════════════════════════════════
// INITIALIZE NAVIGATION
// ════════════════════════════════════════════
function initializeNavigation() {
    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(link => {
        link.addEventListener('click', function (e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            if (targetId && targetId !== '#') {
                const target = document.querySelector(targetId);
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            }
        });
    });

    // Navbar scroll effect
    const navbar = document.querySelector('.navbar');
    if (navbar) {
        window.addEventListener('scroll', function () {
            if (window.scrollY > 50) {
                navbar.style.backgroundColor = '#0d0d1a';
                navbar.style.boxShadow = '0 4px 20px rgba(0, 212, 255, 0.15)';
            } else {
                navbar.style.backgroundColor = 'rgba(0,0,0,0.7)';
                navbar.style.boxShadow = '0 2px 10px rgba(0,0,0,0.3)';
            }
        });
    }

    // Active nav link tracking
    const sections = document.querySelectorAll('section');
    const navLinks = document.querySelectorAll('.nav-links a');

    if (sections.length && navLinks.length) {
        window.addEventListener('scroll', function () {
            let current = '';
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionHeight = section.clientHeight;
                if (window.scrollY >= (sectionTop - 100)) {
                    current = section.getAttribute('id');
                }
            });
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${current}`) {
                    link.classList.add('active');
                }
            });
        });
    }
}

// ════════════════════════════════════════════
// INITIALIZE MODAL
// ════════════════════════════════════════════
function initializeModal() {
    // Make sure modal functions are globally accessible
    window.openLoginModal = openLoginModal;
    window.closeLoginModal = closeLoginModal;
    window.handleOverlayClick = handleOverlayClick;
    window.selectRole = selectRole;
    window.goBack = goBack;
    window.togglePassword = togglePassword;
    window.handleLogin = handleLogin;
}

// ════════════════════════════════════════════
// INITIALIZE SLIDER
// ════════════════════════════════════════════
function initializeSlider() {
    const navBtns = document.querySelectorAll('.slider-nav-btn');
    const dots = document.querySelectorAll('.slider-dot');

    if (navBtns.length) {
        navBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                const slideIndex = parseInt(btn.getAttribute('data-slide'));
                if (!isNaN(slideIndex)) {
                    showSlide(slideIndex);
                }
            });
        });
    }

    if (dots.length) {
        dots.forEach(dot => {
            dot.addEventListener('click', () => {
                const slideIndex = parseInt(dot.getAttribute('data-slide'));
                if (!isNaN(slideIndex)) {
                    showSlide(slideIndex);
                }
            });
        });
    }
}

// ════════════════════════════════════════════
// INITIALIZE REAL-TIME VALIDATION
// ════════════════════════════════════════════
function initializeRealTimeValidation() {
    const forms = ['contactForm', 'ownerRegForm'];

    forms.forEach(formId => {
        const form = document.getElementById(formId);
        if (form) {
            const inputs = form.querySelectorAll('input, select, textarea');
            inputs.forEach(input => {
                input.addEventListener('input', function () {
                    this.classList.remove('error');
                    // Find associated error span
                    const errorId = this.id + 'Error';
                    const errorSpan = document.getElementById(errorId);
                    if (errorSpan) {
                        errorSpan.classList.remove('show');
                    }
                });
            });
        }
    });
}

// ════════════════════════════════════════════
// HERO SLIDER
// ════════════════════════════════════════════
function initializeHeroSlider() {
    const slides = document.querySelectorAll('.hero-slide');
    if (!slides.length) return;
    
    let currentSlide = 0;
    setInterval(() => {
        slides[currentSlide].classList.remove('active');
        currentSlide = (currentSlide + 1) % slides.length;
        slides[currentSlide].classList.add('active');
    }, 4000);
}

// ════════════════════════════════════════════
// SLIDER FUNCTIONALITY
// ════════════════════════════════════════════
let currentSlide = 0;

function showSlide(index) {
    const slides = document.querySelectorAll('.contact-slide');
    const navBtns = document.querySelectorAll('.slider-nav-btn');
    const dots = document.querySelectorAll('.slider-dot');

    if (!slides.length) return;

    // Hide all slides
    slides.forEach((slide, i) => {
        slide.classList.remove('active');
        slide.classList.remove('prev');
        if (i < index) {
            slide.classList.add('prev');
        }
    });

    // Show current slide
    if (slides[index]) {
        slides[index].classList.add('active');
    }

    // Update navigation buttons
    navBtns.forEach((btn, i) => {
        if (i === index) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update dots
    dots.forEach((dot, i) => {
        if (i === index) {
            dot.classList.add('active');
        } else {
            dot.classList.remove('active');
        }
    });

    currentSlide = index;
}

// ════════════════════════════════════════════
// MODAL FUNCTIONS
// ════════════════════════════════════════════
function openLoginModal() {
    console.log('Opening login modal');
    const modal = document.getElementById('loginModal');
    if (modal) {
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
        showStep('role');
        // Reset form
        const emailInput = document.getElementById('emailInput');
        const passwordInput = document.getElementById('passwordInput');
        if (emailInput) emailInput.value = '';
        if (passwordInput) passwordInput.value = '';
        hideError();
    } else {
        console.error('Login modal not found');
    }
}

function closeLoginModal() {
    console.log('Closing login modal');
    const modal = document.getElementById('loginModal');
    if (modal) {
        modal.classList.remove('active');
        document.body.style.overflow = '';
        setTimeout(() => {
            showStep('role');
            selectedRole = null;
            const emailInput = document.getElementById('emailInput');
            const passwordInput = document.getElementById('passwordInput');
            if (emailInput) emailInput.value = '';
            if (passwordInput) passwordInput.value = '';
            hideError();
        }, 300);
    }
}

function handleOverlayClick(e) {
    if (e.target === document.getElementById('loginModal')) {
        closeLoginModal();
    }
}

// Close modal on Escape key
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
        closeLoginModal();
        closeRegModal();
    }
});

function showStep(step) {
    const stepRole = document.getElementById('step-role');
    const stepLogin = document.getElementById('step-login');

    if (stepRole) stepRole.style.display = step === 'role' ? 'block' : 'none';
    if (stepLogin) stepLogin.style.display = step === 'login' ? 'block' : 'none';
}

// ════════════════════════════════════════════
// ROLE CONFIG
// ════════════════════════════════════════════
let selectedRole = null;

const ROLES = {
    admin: {
        label: 'Admin',
        icon: 'fas fa-user-shield',
        subtitle: 'System administrator — full access',
        backendRole: 'admin',
        redirect: `${DASHBOARD_BASE}/admin/dashboard`,
    },
    owner: {
        label: 'Parking Owner',
        icon: 'fas fa-building',
        subtitle: 'Manage your parking site and revenue',
        backendRole: 'parking_owner',
        redirect: `${DASHBOARD_BASE}/owner/dashboard`,
    },
    cashier: {
        label: 'Cashier',
        icon: 'fas fa-cash-register',
        subtitle: 'Handle entries, exits and payments',
        backendRole: null,
        redirect: `${DASHBOARD_BASE}/cashier/dashboard`,
    },
};

function selectRole(role) {
    console.log('Role selected:', role);
    selectedRole = role;
    const cfg = ROLES[role];

    if (!cfg) return;

    const badge = document.getElementById('roleBadge');
    if (badge) {
        badge.className = `role-badge ${role}`;
        badge.innerHTML = `<i class="${cfg.icon}"></i> ${cfg.label}`;
    }

    const roleSubtitle = document.getElementById('roleSubtitle');
    if (roleSubtitle) roleSubtitle.textContent = cfg.subtitle;

    const cashierTypeGroup = document.getElementById('cashierTypeGroup');
    if (cashierTypeGroup) {
        cashierTypeGroup.style.display = role === 'cashier' ? 'block' : 'none';
        const cashierTypeInput = document.getElementById('cashierTypeInput');
        if (cashierTypeInput) cashierTypeInput.value = '';
    }

    showStep('login');
    setTimeout(() => {
        const emailInput = document.getElementById('emailInput');
        if (emailInput) emailInput.focus();
    }, 50);
}

function goBack() {
    showStep('role');
    selectedRole = null;
    hideError();
    const cashierTypeGroup = document.getElementById('cashierTypeGroup');
    if (cashierTypeGroup) cashierTypeGroup.style.display = 'none';
}

function togglePassword() {
    const input = document.getElementById('passwordInput');
    const icon = document.getElementById('eyeIcon');
    if (input && icon) {
        const isHidden = input.type === 'password';
        input.type = isHidden ? 'text' : 'password';
        icon.className = isHidden ? 'fas fa-eye-slash' : 'fas fa-eye';
    }
}

function showError(msg) {
    const errorEl = document.getElementById('loginError');
    const errorMsg = document.getElementById('loginErrorMsg');
    if (errorEl && errorMsg) {
        errorMsg.textContent = msg;
        errorEl.style.display = 'flex';
    }
}

function hideError() {
    const errorEl = document.getElementById('loginError');
    if (errorEl) errorEl.style.display = 'none';
}

// ════════════════════════════════════════════
// LOGIN HANDLER
// ════════════════════════════════════════════
async function handleLogin(e) {
    e.preventDefault();
    console.log('Login attempted');
    hideError();

    const email = document.getElementById('emailInput').value.trim();
    const password = document.getElementById('passwordInput').value;
    const btn = document.getElementById('submitBtn');
    const btnText = document.getElementById('btnText');
    const spinner = document.getElementById('btnSpinner');

    // Validate inputs
    if (!email) {
        showError('Please enter your email address');
        return;
    }
    if (!password) {
        showError('Please enter your password');
        return;
    }

    if (btn) {
        btn.disabled = true;
        if (btnText) btnText.textContent = 'Signing in...';
        if (spinner) spinner.style.display = 'inline-block';
    }

    try {
        console.log('Sending login request to:', `${API_BASE}/api/auth/login/`);

        const response = await fetch(`${API_BASE}/api/auth/login/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password }),
        });

        const data = await response.json();
        console.log('Login response:', data);

        if (!response.ok) {
            throw new Error(data.error || data.detail || data.message || 'Invalid email or password');
        }

        const returnedRole = data.role;

        // Role validation
        if (selectedRole === 'admin' && returnedRole !== 'admin') {
            throw new Error('This account does not have Admin access.');
        }
        if (selectedRole === 'owner' && returnedRole !== 'parking_owner') {
            throw new Error('This account does not have Parking Owner access.');
        }
        if (selectedRole === 'cashier') {
            const cashierType = document.getElementById('cashierTypeInput').value;
            if (!cashierType) {
                throw new Error('Please select your Cashier Type.');
            }
            if (returnedRole !== cashierType) {
                const requestedRoleLabel = cashierType === 'entry_cashier' ? 'Entry Gate Cashier' : 'Exit Gate Cashier';
                throw new Error(`This account does not have access as ${requestedRoleLabel}.`);
            }
        }

        // Store tokens and user info in localStorage
        localStorage.setItem('access_token', data.tokens?.access || data.access);
        localStorage.setItem('refresh_token', data.tokens?.refresh || data.refresh || '');
        localStorage.setItem('user_role', data.role);
        localStorage.setItem('user_id', data.user_id || '');
        localStorage.setItem('user_name', data.name || '');
        if (data.site_id) {
            localStorage.setItem('site_id', data.site_id);
        }

        // Role-based redirect
        let redirectUrl;
        if (returnedRole === 'admin') {
            redirectUrl = `${DASHBOARD_BASE}/admin/dashboard`;
        } else if (returnedRole === 'parking_owner') {
            redirectUrl = `${DASHBOARD_BASE}/owner/dashboard`;
        } else if (returnedRole === 'entry_cashier') {
            redirectUrl = `${DASHBOARD_BASE}/cashier/entry`;
        } else if (returnedRole === 'exit_cashier') {
            redirectUrl = `${DASHBOARD_BASE}/cashier/exit`;
        } else if (returnedRole === 'cashier') {
            redirectUrl = `${DASHBOARD_BASE}/cashier/dashboard`;
        } else {
            redirectUrl = `${DASHBOARD_BASE}/`;
        }

        // Build redirect URL with tokens
        const params = new URLSearchParams({
            access_token: data.tokens?.access || data.access,
            refresh_token: data.tokens?.refresh || data.refresh || '',
            user_role: data.role,
            user_name: data.name || '',
            user_email: email,
            site_id: data.site_id || '',
            user_id: data.user_id || '',
        });

        console.log('Redirecting to:', `${redirectUrl}?${params.toString()}`);

        setTimeout(() => {
            window.location.href = `${redirectUrl}?${params.toString()}`;
        }, 300);

    } catch (err) {
        console.error('Login error:', err);
        if (err.name === 'TypeError' && err.message.includes('fetch')) {
            showError('Cannot connect to server. Please make sure the backend is running (python manage.py runserver)');
        } else {
            showError(err.message || 'Login failed. Please try again.');
        }
    } finally {
        if (btn) {
            btn.disabled = false;
            if (btnText) btnText.textContent = 'Sign In';
            if (spinner) spinner.style.display = 'none';
        }
    }
}

// ════════════════════════════════════════════
// OWNER REGISTRATION MODAL FUNCTIONS
// ════════════════════════════════════════════
function openRegistrationForm() {
    console.log('Opening registration modal');
    const modal = document.getElementById('ownerRegModal');
    if (modal) {
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
}

function closeRegModal() {
    const modal = document.getElementById('ownerRegModal');
    if (modal) {
        modal.classList.remove('active');
        document.body.style.overflow = '';
    }
}

function handleRegOverlayClick(e) {
    if (e.target === document.getElementById('ownerRegModal')) {
        closeRegModal();
    }
}

// Make functions globally accessible
window.openRegistrationForm = openRegistrationForm;
window.closeRegModal = closeRegModal;
window.handleRegOverlayClick = handleRegOverlayClick;
window.submitQuery = submitQuery;
window.submitOwnerRegistration = submitOwnerRegistration;
window.closeSuccessModal = function(e, force = false) {
    if (e && e.stopPropagation) {
        e.stopPropagation();
    }
    if (force || (e && e.target && e.target.id === 'successModal')) {
        const modal = document.getElementById('successModal');
        if (modal) {
            modal.classList.remove('active');
        }
        document.body.style.overflow = '';
    }
};

function handleSuccessDone(e) {
    window.location.href = `${API_BASE}/landing/index.html`;
}

function showSuccessModal(message) {
    const modal = document.getElementById('successModal');
    const msgEl = document.getElementById('successModalMsg');
    if (modal && msgEl) {
        msgEl.textContent = message;
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
}

// ════════════════════════════════════════════
// VALIDATION FUNCTIONS
// ════════════════════════════════════════════
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@([^\s@.,]+\.)+[^\s@.,]{2,}$/;
    return emailRegex.test(email);
}

function isValidPhone(phone) {
    const phoneRegex = /^(03\d{9}|\d{11})$/;
    return phoneRegex.test(phone);
}

function isValidName(name) {
    return name && name.length >= 3 && /^[a-zA-Z\s]+$/.test(name);
}

function showErrorMsg(elementId, message) {
    const errorSpan = document.getElementById(elementId);
    if (errorSpan) {
        errorSpan.textContent = message;
        errorSpan.classList.add('show');
        const input = errorSpan.previousElementSibling?.querySelector('input, select, textarea');
        if (input) input.classList.add('error');
    }
}

function hideErrorMsg(elementId) {
    const errorSpan = document.getElementById(elementId);
    if (errorSpan) {
        errorSpan.classList.remove('show');
        const input = errorSpan.previousElementSibling?.querySelector('input, select, textarea');
        if (input) input.classList.remove('error');
    }
}

function clearFormErrors(formId) {
    const form = document.getElementById(formId);
    if (form) {
        const errors = form.querySelectorAll('.error-msg');
        errors.forEach(error => error.classList.remove('show'));
        const inputs = form.querySelectorAll('input, select, textarea');
        inputs.forEach(input => input.classList.remove('error'));
    }
}

// ════════════════════════════════════════════
// CONTACT QUERY SUBMISSION
// ════════════════════════════════════════════
window.submitQuery = async function (event) {
    event.preventDefault()
    console.log('Submitting contact query')

    clearFormErrors('contactForm')

    const name = document.getElementById('queryName').value.trim()
    const email = document.getElementById('queryEmail').value.trim()
    const phone = document.getElementById('queryPhone').value.trim()
    const queryType = document.getElementById('queryType').value
    const message = document.getElementById('queryMessage').value.trim()

    // Validation - tumhara existing code
    let isValid = true
    if (!name) { showErrorMsg('nameError', 'Full name is required'); isValid = false }
    if (!email) { showErrorMsg('emailError', 'Email is required'); isValid = false }
    if (!queryType) { showErrorMsg('typeError', 'Please select query type'); isValid = false }
    if (!message) { showErrorMsg('messageError', 'Message is required'); isValid = false }
    if (!isValid) return

    // Loading state
    const submitBtn = document.querySelector('#contactForm .submit-btn')
    const btnSpan = submitBtn.querySelector('span')
    const spinner = submitBtn.querySelector('.btn-spinner')
    submitBtn.disabled = true
    btnSpan.textContent = 'Sending...'
    spinner.style.display = 'inline-block'

    try {
        const response = await fetch(`${API_BASE}/api/auth/registration-query/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                full_name: name,
                email: email,
                phone_number: phone,
                query_type: 'general_support',
                message: message,
            })
        });

        const respData = await response.json();
        if (!response.ok) throw new Error(respData.error || 'Submission failed');

        document.getElementById('contactForm').reset();
        showSuccessModal('Thank you! We\'ll respond within 24 hours.');
        // If Owner Registration selected, maybe switch to that slide
        if (queryType === 'owner_registration') {
            setTimeout(() => showSlide(1), 2000);
        }

    } catch (err) {
        alert('Error: ' + err.message);
    } finally {
        submitBtn.disabled = false
        btnSpan.textContent = 'Send Message'
        spinner.style.display = 'none'
    }
}

// ════════════════════════════════════════════
// OWNER REGISTRATION SUBMISSION
// ════════════════════════════════════════════
async function submitOwnerRegistration(event) {
    event.preventDefault();
    console.log('Submitting owner registration');

    clearFormErrors('ownerRegForm');

    const name = document.getElementById('regName').value.trim();
    const email = document.getElementById('regEmail').value.trim();
    const phone = document.getElementById('regPhone').value.trim();
    const city = document.getElementById('regCity').value.trim();
    const siteName = document.getElementById('regSiteName').value.trim();
    const address = document.getElementById('regAddress').value.trim();
    const totalSlots = document.getElementById('regSlots').value;

    let isValid = true;

    if (!name) {
        showErrorMsg('regNameError', 'Full name required');
        isValid = false;
    } else if (!isValidName(name)) {
        showErrorMsg('regNameError', 'Valid name required (min 3 letters)');
        isValid = false;
    }

    if (!email) {
        showErrorMsg('regEmailError', 'Email required');
        isValid = false;
    } else if (!isValidEmail(email)) {
        showErrorMsg('regEmailError', 'Valid email required');
        isValid = false;
    }

    if (!phone) {
        showErrorMsg('regPhoneError', 'Phone number required');
        isValid = false;
    } else if (!isValidPhone(phone)) {
        showErrorMsg('regPhoneError', 'Valid Pakistan number required (e.g., 03001234567)');
        isValid = false;
    }

    if (!city) {
        showErrorMsg('regCityError', 'City required');
        isValid = false;
    }

    if (!siteName) {
        showErrorMsg('regSiteError', 'Site name required');
        isValid = false;
    }

    if (!address) {
        showErrorMsg('regAddressError', 'Address required');
        isValid = false;
    } else if (address.length < 10) {
        showErrorMsg('regAddressError', 'Please provide complete address');
        isValid = false;
    }

    if (!totalSlots) {
        showErrorMsg('regSlotsError', 'Number of slots required');
        isValid = false;
    } else if (totalSlots < 5) {
        showErrorMsg('regSlotsError', 'Minimum 5 slots required');
        isValid = false;
    } else if (totalSlots > 500) {
        showErrorMsg('regSlotsError', 'Maximum 500 slots allowed');
        isValid = false;
    }

    if (!isValid) return;

    // Show loading
    const submitBtn = document.querySelector('#ownerRegForm .submit-btn');
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Submitting...';
    }

    try {
        const response = await fetch(`${API_BASE}/api/auth/registration-query/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                full_name: name,
                email: email,
                phone_number: phone,
                query_type: 'owner_registration',
                proposed_site_name: siteName,
                site_capacity: parseInt(totalSlots),
                message: `City: ${city}\nAddress: ${address}`
            })
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Registration failed');

        document.getElementById('ownerRegForm').reset();
        closeRegModal();
        if (data.credentials) {
            showCredentialsModal(data.credentials.email, data.credentials.temporary_password);
        } else {
            showSuccessModal('Registration submitted! Admin will review and contact you shortly.');
            setTimeout(() => showSlide(2), 2000);
        }

    } catch (err) {
        alert('Error: ' + err.message);
    } finally {
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="fas fa-paper-plane"></i> Submit Registration';
        }
    }
}

// ════════════════════════════════════════════
// CREDENTIALS MODAL & DIRECT LOGIN FUNCTIONS
// ════════════════════════════════════════════
let generatedEmail = "";
let generatedPassword = "";

function showCredentialsModal(email, password) {
    generatedEmail = email;
    generatedPassword = password;
    
    const emailEl = document.getElementById('credEmailText');
    const passEl = document.getElementById('credPasswordText');
    const modal = document.getElementById('credentialsModal');
    
    if (emailEl) emailEl.textContent = email;
    if (passEl) passEl.textContent = password;
    
    if (modal) {
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
    }
}

function closeCredentialsModal() {
    const modal = document.getElementById('credentialsModal');
    if (modal) {
        modal.classList.remove('active');
        document.body.style.overflow = '';
    }
}

function handleCredentialsDone(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    closeCredentialsModal();
    window.location.href = `${API_BASE}/landing/index.html`;
}

async function copyCredentials() {
    const textToCopy = `Email: ${generatedEmail}\nPassword: ${generatedPassword}`;
    try {
        await navigator.clipboard.writeText(textToCopy);
        const copyBtn = document.getElementById('copyCredsBtn');
        const copySpan = copyBtn.querySelector('span');
        if (copySpan) {
            const originalText = copySpan.textContent;
            copySpan.textContent = 'Copied!';
            setTimeout(() => {
                copySpan.textContent = originalText;
            }, 2000);
        }
    } catch (err) {
        alert('Failed to copy credentials: ' + err);
    }
}

async function handleDirectLogin() {
    closeCredentialsModal();
    
    // Auto populate and submit login
    selectedRole = 'owner';
    const emailInput = document.getElementById('emailInput');
    const passwordInput = document.getElementById('passwordInput');
    
    if (emailInput) emailInput.value = generatedEmail;
    if (passwordInput) passwordInput.value = generatedPassword;
    
    // Show login modal but skip role selection, go straight to login form
    const modal = document.getElementById('loginModal');
    if (modal) {
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';
        
        // Setup owner role details in the login modal
        const cfg = ROLES['owner'];
        const badge = document.getElementById('roleBadge');
        if (badge) {
            badge.className = 'role-badge owner';
            badge.innerHTML = `<i class="${cfg.icon}"></i> ${cfg.label}`;
        }
        const roleSubtitle = document.getElementById('roleSubtitle');
        if (roleSubtitle) roleSubtitle.textContent = cfg.subtitle;
        
        showStep('login');
    }
    
    // Auto-trigger login submission!
    const submitBtn = document.getElementById('submitBtn');
    if (submitBtn) {
        // Trigger handleLogin event programmatically
        const mockEvent = { preventDefault: () => {} };
        await handleLogin(mockEvent);
    }
}

window.closeCredentialsModal = closeCredentialsModal;
window.copyCredentials = copyCredentials;
window.handleDirectLogin = handleDirectLogin;
window.handleCredentialsDone = handleCredentialsDone;
window.handleSuccessDone = handleSuccessDone;