-- ClinicCare đã được tạo trên MySQL (localhost:3306, user root, schema cliniccare).
-- Mở MySQL Workbench, kết nối Local instance MySQL80, chọn schema cliniccare để xem và sửa dữ liệu.
-- Mật khẩu đăng nhập web được băm bằng SHA2, không lưu dạng thường.
-- Tài khoản demo:
--   admin@cliniccare.vn / Admin@123
--   doctor@cliniccare.vn / Doctor@123
--   doctor2@cliniccare.vn / Doctor@123
--   user@cliniccare.vn / User@123
--   hung@cliniccare.vn / User@123
--   locked@cliniccare.vn / User@123  (tài khoản đang bị khóa)

CREATE DATABASE IF NOT EXISTS cliniccare
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE cliniccare;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS revenue_by_day;
DROP TABLE IF EXISTS prescription_items;
DROP TABLE IF EXISTS medical_records;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS package_tests;
DROP TABLE IF EXISTS packages;
DROP TABLE IF EXISTS medicines;
DROP TABLE IF EXISTS disease_groups;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS consults;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS branches;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE branches (
  id VARCHAR(20) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  address VARCHAR(255) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  opening_hours VARCHAR(100) NOT NULL DEFAULT '07:00 - 20:00'
);

CREATE TABLE users (
  id VARCHAR(20) PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL,
  password_hash CHAR(64) NOT NULL,
  role ENUM('admin', 'doctor', 'user') NOT NULL DEFAULT 'user',
  gender ENUM('male', 'female', 'other') NOT NULL DEFAULT 'other',
  date_of_birth DATE NULL,
  address VARCHAR(255) NULL,
  avatar_url MEDIUMTEXT NULL,
  verified TINYINT(1) NOT NULL DEFAULT 0,
  verify_code VARCHAR(10) NULL,
  locked TINYINT(1) NOT NULL DEFAULT 0,
  lock_reason VARCHAR(255) NULL,
  doctor_id VARCHAR(20) NULL,
  reset_token VARCHAR(40) NULL,
  reset_expire DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE doctors (
  id VARCHAR(20) PRIMARY KEY,
  user_id VARCHAR(20) NULL,
  branch_id VARCHAR(20) NOT NULL,
  full_name VARCHAR(150) NOT NULL,
  specialty VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL,
  avatar_url MEDIUMTEXT NULL,
  bio VARCHAR(500) NULL,
  CONSTRAINT fk_doctor_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_doctor_branch FOREIGN KEY (branch_id) REFERENCES branches(id)
);

CREATE TABLE packages (
  id VARCHAR(20) PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  tagline VARCHAR(50) NOT NULL,
  price INT NOT NULL,
  test_count INT NOT NULL,
  badge VARCHAR(40) NULL,
  summary VARCHAR(255) NOT NULL
);

CREATE TABLE package_tests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  package_id VARCHAR(20) NOT NULL,
  test_name VARCHAR(150) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  CONSTRAINT fk_test_package FOREIGN KEY (package_id) REFERENCES packages(id)
);

CREATE TABLE appointments (
  id VARCHAR(20) PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  user_id VARCHAR(20) NULL,
  patient_name VARCHAR(150) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(150) NOT NULL,
  gender ENUM('male', 'female', 'other') NOT NULL,
  note TEXT NULL,
  package_id VARCHAR(20) NOT NULL,
  branch_id VARCHAR(20) NOT NULL,
  doctor_id VARCHAR(20) NULL,
  appointment_date DATE NOT NULL,
  appointment_time TIME NOT NULL,
  status ENUM('pending', 'confirmed', 'completed', 'cancelled') NOT NULL,
  payment_method ENUM('momo', 'cash', 'transfer') NOT NULL,
  paid TINYINT(1) NOT NULL DEFAULT 0,
  amount INT NOT NULL,
  refund_status ENUM('pending', 'done') NULL,
  refund_amount INT NOT NULL DEFAULT 0,
  refunded_at DATETIME NULL,
  cancel_request_status ENUM('open', 'approved', 'rejected') NULL,
  cancel_request_reason VARCHAR(255) NULL,
  cancel_request_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_apt_phone (phone),
  INDEX idx_apt_date (appointment_date),
  INDEX idx_apt_doctor_slot (doctor_id, appointment_date, appointment_time),
  CONSTRAINT fk_apt_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_apt_package FOREIGN KEY (package_id) REFERENCES packages(id),
  CONSTRAINT fk_apt_branch FOREIGN KEY (branch_id) REFERENCES branches(id),
  CONSTRAINT fk_apt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE SET NULL
);

CREATE TABLE medical_records (
  id VARCHAR(20) PRIMARY KEY,
  appointment_id VARCHAR(20) NOT NULL UNIQUE,
  patient_user_id VARCHAR(20) NULL,
  doctor_id VARCHAR(20) NULL,
  package_id VARCHAR(20) NULL,
  diagnosis TEXT NULL,
  treatment TEXT NULL,
  notes TEXT NULL,
  status ENUM('new', 'examining', 'completed') NOT NULL DEFAULT 'new',
  updated_at DATETIME NULL,
  CONSTRAINT fk_record_apt FOREIGN KEY (appointment_id) REFERENCES appointments(id)
);

CREATE TABLE prescription_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  record_id VARCHAR(20) NOT NULL,
  medicine_name VARCHAR(150) NOT NULL,
  dosage VARCHAR(100) NULL,
  usage_text VARCHAR(255) NULL,
  days INT NULL,
  quantity VARCHAR(50) NULL,
  note VARCHAR(255) NULL,
  CONSTRAINT fk_rx_record FOREIGN KEY (record_id) REFERENCES medical_records(id) ON DELETE CASCADE
);

CREATE TABLE disease_groups (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE medicines (
  id VARCHAR(20) PRIMARY KEY,
  disease_group VARCHAR(100) NOT NULL,
  name VARCHAR(150) NOT NULL,
  dosage VARCHAR(100) NOT NULL,
  usage_text VARCHAR(255) NOT NULL
);

CREATE TABLE sessions (
  token CHAR(48) PRIMARY KEY,
  user_id VARCHAR(20) NOT NULL,
  expires_at DATETIME NOT NULL,
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE audit_logs (
  id VARCHAR(24) PRIMARY KEY,
  actor_id VARCHAR(20) NULL,
  actor_name VARCHAR(150) NOT NULL,
  action VARCHAR(100) NOT NULL,
  detail VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE consults (
  id VARCHAR(24) PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE VIEW revenue_by_day AS
SELECT appointment_date AS revenue_date,
       SUM(
         CASE
           WHEN refund_status = 'done' THEN GREATEST(amount - refund_amount, 0)
           ELSE amount
         END
       ) AS amount,
       COUNT(*) AS appointment_count
FROM appointments
WHERE paid = 1
GROUP BY appointment_date;

INSERT INTO branches (id, name, address, phone) VALUES
('br-tx', 'ClinicCare Thanh Xuân', '168 Nguyễn Trãi, Thanh Xuân, Hà Nội', '19006688'),
('br-cg', 'ClinicCare Cầu Giấy', '36 Xuân Thủy, Cầu Giấy, Hà Nội', '19006688'),
('br-dn', 'ClinicCare Hải Châu', '120 Lê Duẩn, Hải Châu, Đà Nẵng', '19006688');

INSERT INTO users (id, full_name, email, phone, password_hash, role, gender, date_of_birth, address, verified, locked, lock_reason) VALUES
('user-admin', 'Trần Quốc Bảo', 'admin@cliniccare.vn', '0901000001', SHA2('cliniccare:Admin@123', 256), 'admin', 'male', '1988-03-12', 'Thanh Xuân, Hà Nội', 1, 0, NULL),
('user-doctor', 'Nguyễn Minh Anh', 'doctor@cliniccare.vn', '0901000002', SHA2('cliniccare:Doctor@123', 256), 'doctor', 'female', '1990-07-19', 'Đống Đa, Hà Nội', 1, 0, NULL),
('user-doctor2', 'Lê Thu Hà', 'doctor2@cliniccare.vn', '0901000003', SHA2('cliniccare:Doctor@123', 256), 'doctor', 'female', '1992-11-02', 'Cầu Giấy, Hà Nội', 1, 0, NULL),
('user-duong', 'Nguyễn Thùy Dương', 'user@cliniccare.vn', '0912345678', SHA2('cliniccare:User@123', 256), 'user', 'female', '1994-04-12', 'Thanh Xuân, Hà Nội', 1, 0, NULL),
('user-hung', 'Trần Văn Hùng', 'hung@cliniccare.vn', '0988123456', SHA2('cliniccare:User@123', 256), 'user', 'male', '1981-09-30', 'Cầu Giấy, Hà Nội', 1, 0, NULL),
('user-locked', 'Phạm Thị Lan', 'locked@cliniccare.vn', '0977000111', SHA2('cliniccare:User@123', 256), 'user', 'female', '1996-01-20', 'Hải Châu, Đà Nẵng', 1, 1, 'Đặt lịch nhiều lần nhưng không đến khám');

INSERT INTO doctors (id, user_id, branch_id, full_name, specialty, email, bio) VALUES
('doc-anh', 'user-doctor', 'br-tx', 'BS. Nguyễn Minh Anh', 'Tim mạch', 'doctor@cliniccare.vn', 'Theo dõi tăng huyết áp, rối loạn lipid máu và bệnh tim mạch.'),
('doc-ha', 'user-doctor2', 'br-tx', 'BS. Lê Thu Hà', 'Sản phụ khoa', 'doctor2@cliniccare.vn', 'Khám sức khỏe sinh sản và chăm sóc phụ khoa định kỳ.'),
('doc-long', NULL, 'br-tx', 'BS. Phạm Đức Long', 'Nội tổng quát', 'long.pham@cliniccare.vn', 'Khám tổng quát và theo dõi bệnh lý nội khoa thường gặp.'),
('doc-chi', NULL, 'br-cg', 'BS. Hoàng Mai Chi', 'Xét nghiệm', 'chi.hoang@cliniccare.vn', 'Phụ trách xét nghiệm và giải thích chỉ số cận lâm sàng.'),
('doc-nam', NULL, 'br-cg', 'BS. Võ Thành Nam', 'Tim mạch', 'nam.vo@cliniccare.vn', 'Tầm soát nguy cơ tim mạch cho người trưởng thành.'),
('doc-khoa', NULL, 'br-dn', 'BS. Đặng Quốc Khoa', 'Nội tổng quát', 'khoa.dang@cliniccare.vn', 'Khám lâm sàng và tư vấn gói sức khỏe tại Đà Nẵng.');

UPDATE users SET doctor_id = 'doc-anh' WHERE id = 'user-doctor';
UPDATE users SET doctor_id = 'doc-ha' WHERE id = 'user-doctor2';

INSERT INTO packages (id, name, tagline, price, test_count, badge, summary) VALUES
('pkg-silver', 'Tổng quát Silver', '23 chỉ số', 846000, 23, 'Phổ biến', 'Tầm soát sức khỏe định kỳ với các chỉ số nền tảng.'),
('pkg-gold', 'Tổng quát Gold', '30 chỉ số', 1766000, 30, NULL, 'Mở rộng đánh giá chuyển hóa, gan, thận và tuyến giáp.'),
('pkg-diamond', 'Tổng quát Diamond', '38 chỉ số', 2575000, 38, 'Chuyên sâu', 'Gói tổng quát chuyên sâu kèm chẩn đoán hình ảnh.'),
('pkg-well-dia', 'Wellness Diamond', '48 chỉ số', 6970000, 48, NULL, 'Chăm sóc sức khỏe toàn diện, tư vấn dinh dưỡng và lối sống.'),
('pkg-well-elite', 'Wellness Elite', '56 chỉ số', 8995000, 56, 'Cao cấp', 'Tầm soát cao cấp cho người cần theo dõi chuyên sâu.'),
('pkg-parasite', 'Xét nghiệm ký sinh trùng', '12 chỉ số', 1053000, 12, NULL, 'Sàng lọc ký sinh trùng đường ruột và các chỉ số liên quan.'),
('pkg-repro', 'Sức khỏe sinh sản', '16 chỉ số', 785000, 16, NULL, 'Khám và xét nghiệm định hướng sức khỏe sinh sản.'),
('pkg-vitamin', 'Vitamin – Khoáng chất', '14 chỉ số', 1121000, 14, NULL, 'Đánh giá vitamin, khoáng chất và tình trạng thiếu vi chất.');

INSERT INTO package_tests (package_id, test_name, sort_order) VALUES
('pkg-silver', 'Công thức máu', 1), ('pkg-silver', 'Nhóm máu ABO/Rh', 2), ('pkg-silver', 'Đường huyết lúc đói', 3),
('pkg-silver', 'Cholesterol toàn phần', 4), ('pkg-silver', 'HDL-C', 5), ('pkg-silver', 'LDL-C', 6),
('pkg-silver', 'Triglycerid', 7), ('pkg-silver', 'AST (GOT)', 8), ('pkg-silver', 'ALT (GPT)', 9),
('pkg-silver', 'Ure', 10), ('pkg-silver', 'Creatinin', 11), ('pkg-silver', 'Tổng phân tích nước tiểu', 12),
('pkg-silver', 'Đo huyết áp', 13), ('pkg-silver', 'Đo chỉ số BMI', 14), ('pkg-silver', 'Khám nội tổng quát', 15),
('pkg-silver', 'Khám mắt', 16), ('pkg-silver', 'Khám tai mũi họng', 17), ('pkg-silver', 'Khám răng hàm mặt', 18),
('pkg-silver', 'Điện tâm đồ', 19), ('pkg-silver', 'X-quang ngực thẳng', 20), ('pkg-silver', 'Siêu âm bụng tổng quát', 21),
('pkg-silver', 'HBsAg', 22), ('pkg-silver', 'Tư vấn dinh dưỡng', 23),
('pkg-gold', 'Công thức máu', 1), ('pkg-gold', 'Đường huyết lúc đói', 2), ('pkg-gold', 'HbA1c', 3),
('pkg-gold', 'Cholesterol toàn phần', 4), ('pkg-gold', 'HDL-C', 5), ('pkg-gold', 'LDL-C', 6),
('pkg-gold', 'Triglycerid', 7), ('pkg-gold', 'AST (GOT)', 8), ('pkg-gold', 'ALT (GPT)', 9),
('pkg-gold', 'GGT', 10), ('pkg-gold', 'Ure', 11), ('pkg-gold', 'Creatinin', 12),
('pkg-gold', 'eGFR', 13), ('pkg-gold', 'Acid uric', 14), ('pkg-gold', 'TSH', 15),
('pkg-gold', 'FT4', 16), ('pkg-gold', 'Tổng phân tích nước tiểu', 17), ('pkg-gold', 'CRP', 18),
('pkg-gold', 'HBsAg', 19), ('pkg-gold', 'Anti-HBs', 20), ('pkg-gold', 'Điện tâm đồ', 21),
('pkg-gold', 'X-quang ngực thẳng', 22), ('pkg-gold', 'Siêu âm bụng tổng quát', 23), ('pkg-gold', 'Siêu âm tuyến giáp', 24),
('pkg-gold', 'Khám nội tổng quát', 25), ('pkg-gold', 'Khám mắt', 26), ('pkg-gold', 'Đo huyết áp', 27),
('pkg-gold', 'Đo chỉ số BMI', 28), ('pkg-gold', 'Vitamin D', 29), ('pkg-gold', 'Tư vấn dinh dưỡng', 30),
('pkg-diamond', 'Công thức máu', 1), ('pkg-diamond', 'Đường huyết lúc đói', 2), ('pkg-diamond', 'HbA1c', 3),
('pkg-diamond', 'Cholesterol toàn phần', 4), ('pkg-diamond', 'HDL-C', 5), ('pkg-diamond', 'LDL-C', 6),
('pkg-diamond', 'Triglycerid', 7), ('pkg-diamond', 'AST (GOT)', 8), ('pkg-diamond', 'ALT (GPT)', 9),
('pkg-diamond', 'GGT', 10), ('pkg-diamond', 'Bilirubin toàn phần', 11), ('pkg-diamond', 'Ure', 12),
('pkg-diamond', 'Creatinin', 13), ('pkg-diamond', 'eGFR', 14), ('pkg-diamond', 'Acid uric', 15),
('pkg-diamond', 'TSH', 16), ('pkg-diamond', 'FT4', 17), ('pkg-diamond', 'CRP', 18),
('pkg-diamond', 'HBsAg', 19), ('pkg-diamond', 'Anti-HCV', 20), ('pkg-diamond', 'HIV Ag/Ab', 21),
('pkg-diamond', 'CEA', 22), ('pkg-diamond', 'AFP', 23), ('pkg-diamond', 'Điện tâm đồ', 24),
('pkg-diamond', 'Siêu âm tim', 25), ('pkg-diamond', 'Siêu âm bụng tổng quát', 26), ('pkg-diamond', 'X-quang ngực thẳng', 27),
('pkg-diamond', 'Khám nội tổng quát', 28), ('pkg-diamond', 'Khám mắt', 29), ('pkg-diamond', 'Khám tai mũi họng', 30),
('pkg-diamond', 'Đo huyết áp', 31), ('pkg-diamond', 'Đo chỉ số BMI', 32), ('pkg-diamond', 'Vitamin D', 33),
('pkg-diamond', 'Vitamin B12', 34), ('pkg-diamond', 'Ferritin', 35), ('pkg-diamond', 'Canxi toàn phần', 36),
('pkg-diamond', 'Tổng phân tích nước tiểu', 37), ('pkg-diamond', 'Tư vấn dinh dưỡng', 38),
('pkg-parasite', 'Trứng giun sán', 1), ('pkg-parasite', 'Amip trong phân', 2), ('pkg-parasite', 'Strongyloides', 3),
('pkg-parasite', 'Hồng cầu trong phân', 4), ('pkg-parasite', 'Soi tươi', 5), ('pkg-parasite', 'Nhuộm Gram', 6),
('pkg-parasite', 'Công thức máu', 7), ('pkg-parasite', 'CRP', 8), ('pkg-parasite', 'Albumin', 9),
('pkg-parasite', 'Sắt huyết thanh', 10), ('pkg-parasite', 'Ferritin', 11), ('pkg-parasite', 'Tổng phân tích nước tiểu', 12),
('pkg-repro', 'Khám phụ khoa / nam khoa', 1), ('pkg-repro', 'Siêu âm phụ khoa', 2), ('pkg-repro', 'Pap smear', 3),
('pkg-repro', 'Soi tươi', 4), ('pkg-repro', 'Nhuộm Gram', 5), ('pkg-repro', 'Beta-hCG', 6),
('pkg-repro', 'Nội tiết tố nữ', 7), ('pkg-repro', 'TSH', 8), ('pkg-repro', 'FT4', 9),
('pkg-repro', 'Công thức máu', 10), ('pkg-repro', 'Đường huyết lúc đói', 11), ('pkg-repro', 'HIV Ag/Ab', 12),
('pkg-repro', 'HBsAg', 13), ('pkg-repro', 'Giang mai', 14), ('pkg-repro', 'Chlamydia', 15),
('pkg-repro', 'Tư vấn sinh sản', 16),
('pkg-vitamin', 'Vitamin D', 1), ('pkg-vitamin', 'Vitamin B12', 2), ('pkg-vitamin', 'Folate', 3),
('pkg-vitamin', 'Vitamin A', 4), ('pkg-vitamin', 'Vitamin E', 5), ('pkg-vitamin', 'Vitamin C', 6),
('pkg-vitamin', 'Sắt huyết thanh', 7), ('pkg-vitamin', 'Ferritin', 8), ('pkg-vitamin', 'Canxi toàn phần', 9),
('pkg-vitamin', 'Magie', 10), ('pkg-vitamin', 'Kẽm huyết thanh', 11), ('pkg-vitamin', 'Đồng huyết thanh', 12),
('pkg-vitamin', 'Albumin', 13), ('pkg-vitamin', 'Tư vấn dinh dưỡng', 14);

INSERT INTO package_tests (package_id, test_name, sort_order)
SELECT 'pkg-well-dia', test_name, sort_order FROM package_tests WHERE package_id = 'pkg-diamond';
INSERT INTO package_tests (package_id, test_name, sort_order) VALUES
('pkg-well-dia', 'Đo mật độ xương', 39), ('pkg-well-dia', 'Homocysteine', 40), ('pkg-well-dia', 'CK-MB', 41),
('pkg-well-dia', 'NT-proBNP', 42), ('pkg-well-dia', 'Magie', 43), ('pkg-well-dia', 'Kẽm huyết thanh', 44),
('pkg-well-dia', 'Đánh giá giấc ngủ', 45), ('pkg-well-dia', 'Đánh giá stress', 46),
('pkg-well-dia', 'Khám răng hàm mặt', 47), ('pkg-well-dia', 'Khám tai mũi họng', 48);

INSERT INTO package_tests (package_id, test_name, sort_order)
SELECT 'pkg-well-elite', test_name, sort_order FROM package_tests WHERE package_id = 'pkg-well-dia';
INSERT INTO package_tests (package_id, test_name, sort_order) VALUES
('pkg-well-elite', 'Troponin I', 49), ('pkg-well-elite', 'CA 19-9', 50), ('pkg-well-elite', 'CA 125', 51),
('pkg-well-elite', 'PSA toàn phần', 52), ('pkg-well-elite', 'Anti-HBs', 53), ('pkg-well-elite', 'Folate', 54),
('pkg-well-elite', 'Vitamin A', 55), ('pkg-well-elite', 'Vitamin E', 56);

INSERT INTO disease_groups (name) VALUES
('Tim mạch'), ('Huyết áp'), ('Tiểu đường'), ('Tiêu hóa'), ('Giảm đau - hạ sốt'), ('Vitamin và khoáng chất'), ('Dị ứng');

INSERT INTO medicines (id, disease_group, name, dosage, usage_text) VALUES
('med-1', 'Huyết áp', 'Amlodipine', '5mg', 'Uống 1 viên mỗi sáng'),
('med-2', 'Huyết áp', 'Losartan', '50mg', 'Uống 1 viên mỗi sáng'),
('med-3', 'Tim mạch', 'Rosuvastatin', '10mg', 'Uống 1 viên buổi tối'),
('med-4', 'Tim mạch', 'Aspirin', '81mg', 'Uống 1 viên sau ăn'),
('med-5', 'Tiểu đường', 'Metformin', '500mg', 'Uống 1 viên sau ăn sáng và tối'),
('med-6', 'Tiểu đường', 'Gliclazide', '30mg', 'Uống 1 viên trước ăn sáng'),
('med-7', 'Tiêu hóa', 'Omeprazole', '20mg', 'Uống 1 viên trước ăn sáng'),
('med-8', 'Tiêu hóa', 'Domperidone', '10mg', 'Uống 1 viên trước ăn'),
('med-9', 'Giảm đau - hạ sốt', 'Paracetamol', '500mg', 'Uống khi sốt hoặc đau, cách 6 giờ'),
('med-10', 'Vitamin và khoáng chất', 'Vitamin D3', '1000IU', 'Uống 1 viên sau ăn sáng'),
('med-11', 'Vitamin và khoáng chất', 'Kẽm gluconat', '10mg', 'Uống 1 viên sau ăn'),
('med-12', 'Dị ứng', 'Cetirizine', '10mg', 'Uống 1 viên buổi tối');

INSERT INTO appointments (
  id, code, user_id, patient_name, phone, email, gender, note, package_id, branch_id, doctor_id,
  appointment_date, appointment_time, status, payment_method, paid, amount
) VALUES
('apt-duong-old', 'CC-DUONG1', 'user-duong', 'Nguyễn Thùy Dương', '0912345678', 'user@cliniccare.vn', 'female',
 'Đau đầu nhẹ, mệt mỏi kéo dài trong 2 tuần gần đây.', 'pkg-gold', 'br-tx', 'doc-anh',
 DATE_SUB(CURDATE(), INTERVAL 12 DAY), '09:00:00', 'completed', 'transfer', 1, 1766000),
('apt-duong-next', 'CC-DUONG2', 'user-duong', 'Nguyễn Thùy Dương', '0912345678', 'user@cliniccare.vn', 'female',
 'Tái khám theo hẹn.', 'pkg-silver', 'br-tx', 'doc-long',
 DATE_ADD(CURDATE(), INTERVAL 4 DAY), '15:00:00', 'confirmed', 'momo', 1, 846000),
('apt-today-1', 'CC-TODAY01', 'user-duong', 'Nguyễn Thùy Dương', '0912345678', 'user@cliniccare.vn', 'female',
 'Mệt, khó ngủ, muốn kiểm tra vitamin.', 'pkg-vitamin', 'br-tx', 'doc-anh',
 CURDATE(), '09:30:00', 'confirmed', 'cash', 0, 1121000),
('apt-today-2', 'CC-TODAY02', 'user-hung', 'Trần Văn Hùng', '0988123456', 'hung@cliniccare.vn', 'male',
 'Kiểm tra mỡ máu.', 'pkg-diamond', 'br-cg', 'doc-nam',
 CURDATE(), '10:30:00', 'confirmed', 'transfer', 1, 2575000),
('apt-cancel-paid', 'CC-HUY001', 'user-hung', 'Trần Văn Hùng', '0988123456', 'hung@cliniccare.vn', 'male',
 'Bận công tác, đã thanh toán chuyển khoản.', 'pkg-repro', 'br-tx', 'doc-ha',
 DATE_SUB(CURDATE(), INTERVAL 2 DAY), '14:00:00', 'cancelled', 'transfer', 1, 785000),
('apt-cancel-open', 'CC-YCHUY1', NULL, 'Lê Ngọc Mai', '0933555777', 'mai.le@cliniccare.vn', 'female',
 'Khám tổng quát.', 'pkg-silver', 'br-dn', 'doc-khoa',
 DATE_ADD(CURDATE(), INTERVAL 6 DAY), '08:30:00', 'confirmed', 'momo', 1, 846000);

UPDATE appointments
SET refund_status = 'pending', cancel_request_status = NULL
WHERE id = 'apt-cancel-paid';

UPDATE appointments
SET cancel_request_status = 'open',
    cancel_request_reason = 'Đổi lịch công tác đột xuất, nhờ phòng khám hỗ trợ hủy.',
    cancel_request_at = NOW()
WHERE id = 'apt-cancel-open';

INSERT INTO appointments (
  id, code, user_id, patient_name, phone, email, gender, note, package_id, branch_id, doctor_id,
  appointment_date, appointment_time, status, payment_method, paid, amount
)
SELECT
  CONCAT('apt-m', m.n, '-', d.day),
  CONCAT('CC-M', m.n, d.day),
  IF(d.day = 4, 'user-hung', NULL),
  IF(d.day = 4, 'Trần Văn Hùng', CONCAT('Khách hàng ', m.n, '.', d.day)),
  IF(d.day = 4, '0988123456', CONCAT('0903', LPAD(100000 + m.n * 20 + d.day, 6, '0'))),
  IF(d.day = 4, 'hung@cliniccare.vn', CONCAT('khach', m.n, d.day, '@cliniccare.vn')),
  IF(d.day = 4, 'male', 'female'),
  'Khám định kỳ theo gói.',
  ELT(1 + (m.n + d.ord) % 6, 'pkg-silver', 'pkg-gold', 'pkg-diamond', 'pkg-vitamin', 'pkg-repro', 'pkg-parasite'),
  ELT(1 + (m.n + d.ord) % 3, 'br-tx', 'br-cg', 'br-dn'),
  ELT(1 + (m.n + d.ord) % 6, 'doc-anh', 'doc-long', 'doc-ha', 'doc-nam', 'doc-chi', 'doc-khoa'),
  DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL m.n MONTH), INTERVAL (d.day - 1) DAY),
  ELT(d.ord, '08:00:00', '09:30:00', '14:00:00'),
  'completed', 'transfer', 1,
  ELT(1 + (m.n + d.ord) % 6, 846000, 1766000, 2575000, 1121000, 785000, 1053000)
FROM
  (SELECT 0 AS n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) m
  JOIN (
    SELECT 4 AS day, 1 AS ord UNION SELECT 12, 2 UNION SELECT 18, 3
  ) d
WHERE DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL m.n MONTH), INTERVAL (d.day - 1) DAY) < CURDATE();

INSERT INTO medical_records (id, appointment_id, patient_user_id, doctor_id, package_id, diagnosis, treatment, notes, status, updated_at)
SELECT CONCAT('rec-', id), id, user_id, doctor_id, package_id,
  'Theo dõi sức khỏe định kỳ, chưa ghi nhận bất thường nặng.',
  'Duy trì chế độ ăn và tái khám theo gói.',
  'Đã tư vấn kết quả xét nghiệm.',
  'completed', NOW()
FROM appointments
WHERE status = 'completed' AND id <> 'apt-duong-old';

INSERT INTO medical_records (id, appointment_id, patient_user_id, doctor_id, package_id, diagnosis, treatment, notes, status, updated_at)
VALUES (
  'rec-duong-old', 'apt-duong-old', 'user-duong', 'doc-anh', 'pkg-gold',
  'Đau đầu do căng thẳng, cần theo dõi huyết áp.',
  'Nghỉ ngơi, uống đủ nước, hạn chế cà phê, tái khám sau 2 tuần.',
  'Không ghi nhận bệnh lý nền. Dị ứng Penicillin.',
  'completed', NOW()
);

INSERT INTO prescription_items (record_id, medicine_name, dosage, usage_text, days, quantity, note) VALUES
('rec-duong-old', 'Paracetamol', '500mg', 'Uống khi đau, cách 6 giờ', 3, '6 viên', 'Không quá 4g paracetamol/ngày'),
('rec-duong-old', 'Vitamin D3', '1000IU', 'Mỗi ngày 1 viên sau ăn sáng', 14, '14 viên', NULL);

INSERT INTO audit_logs (id, actor_id, actor_name, action, detail) VALUES
('log-seed', 'user-admin', 'Trần Quốc Bảo', 'Khởi tạo dữ liệu', 'Nhập dữ liệu mẫu ClinicCare vào MySQL');
