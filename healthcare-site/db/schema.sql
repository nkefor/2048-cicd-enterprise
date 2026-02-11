-- Healthcare Practice Database Schema

-- Patients table
CREATE TABLE IF NOT EXISTS patients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    phone TEXT,
    date_of_birth TEXT,
    gender TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    insurance_provider TEXT,
    insurance_id TEXT,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Appointments table
CREATE TABLE IF NOT EXISTS appointments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    service_type TEXT NOT NULL CHECK(service_type IN ('telehealth', 'dot_physical', 'consultation', 'follow_up')),
    appointment_date TEXT NOT NULL,
    appointment_time TEXT NOT NULL,
    duration_minutes INTEGER DEFAULT 30,
    status TEXT DEFAULT 'scheduled' CHECK(status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show')),
    notes TEXT,
    telehealth_link TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    appointment_id INTEGER,
    amount INTEGER NOT NULL,
    currency TEXT DEFAULT 'usd',
    stripe_payment_intent_id TEXT,
    stripe_charge_id TEXT,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'processing', 'succeeded', 'failed', 'refunded')),
    description TEXT,
    payment_method TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
);

-- DOT Physical Records
CREATE TABLE IF NOT EXISTS dot_physicals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    appointment_id INTEGER,
    exam_date TEXT NOT NULL,
    certificate_expiry TEXT,
    vision_test_passed INTEGER,
    hearing_test_passed INTEGER,
    blood_pressure_systolic INTEGER,
    blood_pressure_diastolic INTEGER,
    pulse_rate INTEGER,
    urinalysis_result TEXT,
    medical_determination TEXT CHECK(medical_determination IN ('qualified', 'temporarily_disqualified', 'disqualified', 'pending')),
    restrictions TEXT,
    examiner_notes TEXT,
    certificate_issued INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(id)
);

-- Telehealth Sessions
CREATE TABLE IF NOT EXISTS telehealth_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER NOT NULL,
    patient_id INTEGER NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'waiting' CHECK(status IN ('waiting', 'active', 'completed', 'expired')),
    started_at DATETIME,
    ended_at DATETIME,
    duration_seconds INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id),
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);

-- Intake Forms
CREATE TABLE IF NOT EXISTS intake_forms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    form_type TEXT NOT NULL CHECK(form_type IN ('new_patient', 'dot_physical', 'telehealth_consent', 'hipaa_consent')),
    form_data TEXT NOT NULL,
    signed INTEGER DEFAULT 0,
    signed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);

-- Admin Users
CREATE TABLE IF NOT EXISTS admin_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'provider' CHECK(role IN ('provider', 'admin', 'staff')),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    npi_number TEXT,
    credentials TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Available Time Slots
CREATE TABLE IF NOT EXISTS availability (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    day_of_week INTEGER NOT NULL CHECK(day_of_week BETWEEN 0 AND 6),
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    service_type TEXT,
    is_active INTEGER DEFAULT 1
);

-- Messages
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    sender_type TEXT NOT NULL CHECK(sender_type IN ('patient', 'provider')),
    subject TEXT,
    body TEXT NOT NULL,
    is_read INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(id)
);

-- Insert default availability (Mon-Fri, 9 AM - 5 PM)
INSERT OR IGNORE INTO availability (id, day_of_week, start_time, end_time, service_type, is_active)
VALUES
    (1, 1, '09:00', '17:00', 'telehealth', 1),
    (2, 2, '09:00', '17:00', 'telehealth', 1),
    (3, 3, '09:00', '17:00', 'telehealth', 1),
    (4, 4, '09:00', '17:00', 'telehealth', 1),
    (5, 5, '09:00', '17:00', 'telehealth', 1),
    (6, 1, '09:00', '17:00', 'dot_physical', 1),
    (7, 2, '09:00', '17:00', 'dot_physical', 1),
    (8, 3, '09:00', '17:00', 'dot_physical', 1),
    (9, 4, '09:00', '17:00', 'dot_physical', 1),
    (10, 5, '09:00', '17:00', 'dot_physical', 1);
