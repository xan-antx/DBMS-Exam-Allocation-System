-- ============================================================
-- Course: UCS310 - Database Management Systems
-- Project: Examination Hall Seat Allocation System
-- MySQL version (equivalent to Oracle schema)
-- ============================================================

CREATE DATABASE IF NOT EXISTS seating_allocation;
USE seating_allocation;

-- ── Drop in reverse dependency order ──────────────────────
DROP TABLE IF EXISTS Allocation;
DROP TABLE IF EXISTS Student_Course;
DROP TABLE IF EXISTS Exam_Schedule;
DROP TABLE IF EXISTS Hall;
DROP TABLE IF EXISTS Course;
DROP TABLE IF EXISTS Student;

-- ============================================================
-- TABLE CREATION
-- ============================================================

CREATE TABLE Student (
    student_id  INT PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL,
    roll_no     VARCHAR(20)  UNIQUE NOT NULL,
    branch      VARCHAR(20)
);

CREATE TABLE Course (
    course_id   INT PRIMARY KEY,
    title       VARCHAR(50)  NOT NULL,
    dept        VARCHAR(20)
);

CREATE TABLE Hall (
    hall_id     INT PRIMARY KEY,
    hall_name   VARCHAR(30)  NOT NULL,
    capacity    INT          NOT NULL CHECK (capacity > 0)
);

CREATE TABLE Exam_Schedule (
    exam_id     INT PRIMARY KEY,
    course_id   INT,
    exam_date   DATE,
    FOREIGN KEY (course_id) REFERENCES Course(course_id)
);

CREATE TABLE Student_Course (
    student_id  INT,
    course_id   INT,
    PRIMARY KEY (student_id, course_id),
    FOREIGN KEY (student_id) REFERENCES Student(student_id),
    FOREIGN KEY (course_id)  REFERENCES Course(course_id)
);

-- alloc_seq equivalent: AUTO_INCREMENT on Allocation
CREATE TABLE Allocation (
    alloc_id        INT PRIMARY KEY AUTO_INCREMENT,
    exam_id         INT,
    student_id      INT,
    hall_id         INT,
    seat_no         INT,
    allocation_date DATE,
    FOREIGN KEY (exam_id)    REFERENCES Exam_Schedule(exam_id),
    FOREIGN KEY (student_id) REFERENCES Student(student_id),
    FOREIGN KEY (hall_id)    REFERENCES Hall(hall_id),
    UNIQUE KEY uq_student_exam (exam_id, student_id),
    UNIQUE KEY uq_seat_exam    (exam_id, hall_id, seat_no)
);

-- ============================================================
-- TRIGGER — prevents inserting if hall is full
-- Mirrors Oracle: hall_capacity_trg
-- ============================================================

DROP TRIGGER IF EXISTS hall_capacity_trg;

DELIMITER //
CREATE TRIGGER hall_capacity_trg
BEFORE INSERT ON Allocation
FOR EACH ROW
BEGIN
    DECLARE curr_allocated INT DEFAULT 0;
    DECLARE max_capacity   INT DEFAULT 0;

    SELECT COUNT(*) INTO curr_allocated
    FROM Allocation
    WHERE hall_id = NEW.hall_id AND exam_id = NEW.exam_id;

    SELECT capacity INTO max_capacity
    FROM Hall
    WHERE hall_id = NEW.hall_id;

    IF curr_allocated >= max_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Hall is completely full';
    END IF;
END //
DELIMITER ;

-- ============================================================
-- PROCEDURE — allocate_random_seats
-- Mirrors Oracle: allocate_random_seats(curr_exam_id)
-- ============================================================

DROP PROCEDURE IF EXISTS allocate_random_seats;

DELIMITER //
CREATE PROCEDURE allocate_random_seats(IN curr_exam_id INT)
BEGIN
    DECLARE done          INT DEFAULT 0;
    DECLARE v_student_id  INT;
    DECLARE v_name        VARCHAR(50);
    DECLARE v_roll        VARCHAR(20);
    DECLARE total_cap     INT DEFAULT 0;
    DECLARE total_stu     INT DEFAULT 0;
    DECLARE selected_hall INT;
    DECLARE hall_cap      INT;
    DECLARE selected_seat INT;
    DECLARE retries       INT;
    DECLARE inserted      INT DEFAULT 0;

    DECLARE student_cur CURSOR FOR
        SELECT s.student_id, s.name, s.roll_no
        FROM Student s
        JOIN Student_Course sc ON s.student_id = sc.student_id
        JOIN Exam_Schedule   es ON sc.course_id  = es.course_id
        WHERE es.exam_id = curr_exam_id
        ORDER BY RAND();

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SELECT SUM(capacity) INTO total_cap FROM Hall;
    SELECT COUNT(*) INTO total_stu
    FROM Student_Course sc
    JOIN Exam_Schedule es ON sc.course_id = es.course_id
    WHERE es.exam_id = curr_exam_id;

    IF total_stu > total_cap THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Not enough seats across all halls';
    END IF;

    OPEN student_cur;

    stud_loop: LOOP
        FETCH student_cur INTO v_student_id, v_name, v_roll;
        IF done THEN LEAVE stud_loop; END IF;

        SET inserted = 0;
        SET retries  = 0;

        WHILE inserted = 0 AND retries < 200 DO
            SET retries = retries + 1;

            SELECT h.hall_id, h.capacity
            INTO selected_hall, hall_cap
            FROM Hall h
            WHERE (
                SELECT COUNT(*) FROM Allocation a
                WHERE a.hall_id = h.hall_id AND a.exam_id = curr_exam_id
            ) < h.capacity
            ORDER BY RAND()
            LIMIT 1;

            SET selected_seat = FLOOR(1 + RAND() * hall_cap);

            BEGIN
                DECLARE CONTINUE HANDLER FOR 1062 BEGIN END;

                INSERT INTO Allocation (exam_id, student_id, hall_id, seat_no, allocation_date)
                VALUES (curr_exam_id, v_student_id, selected_hall, selected_seat, CURDATE());

                IF ROW_COUNT() > 0 THEN
                    SET inserted = 1;
                END IF;
            END;
        END WHILE;

        IF inserted = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Allocation failed: could not find a free seat';
        END IF;

    END LOOP;

    CLOSE student_cur;
END //
DELIMITER ;

-- ============================================================
-- SAMPLE DATA
-- ============================================================

INSERT INTO Student VALUES (1, 'Amit',   'CS101', 'CSE');
INSERT INTO Student VALUES (2, 'Neha',   'CS102', 'CSE');
INSERT INTO Student VALUES (3, 'Rahul',  'EE101', 'EE');
INSERT INTO Student VALUES (4, 'Simran', 'ME101', 'ME');
INSERT INTO Student VALUES (5, 'Arjun',  'CS103', 'CSE');
INSERT INTO Student VALUES (6, 'Priya',  'EC101', 'ECE');

INSERT INTO Course VALUES (101, 'DBMS', 'CSE');
INSERT INTO Course VALUES (102, 'Data Structures', 'CSE');
INSERT INTO Course VALUES (103, 'Networks', 'ECE');

INSERT INTO Hall VALUES (1, 'Hall A', 20);
INSERT INTO Hall VALUES (2, 'Hall B', 20);
INSERT INTO Hall VALUES (3, 'Hall C', 15);

INSERT INTO Exam_Schedule VALUES (1, 101, '2026-05-10');
INSERT INTO Exam_Schedule VALUES (2, 102, '2026-05-12');
INSERT INTO Exam_Schedule VALUES (3, 103, '2026-05-14');

INSERT INTO Student_Course VALUES (1, 101);
INSERT INTO Student_Course VALUES (2, 101);
INSERT INTO Student_Course VALUES (3, 101);
INSERT INTO Student_Course VALUES (4, 101);
INSERT INTO Student_Course VALUES (5, 101);
INSERT INTO Student_Course VALUES (6, 101);
INSERT INTO Student_Course VALUES (1, 102);
INSERT INTO Student_Course VALUES (2, 102);
INSERT INTO Student_Course VALUES (3, 102);
INSERT INTO Student_Course VALUES (6, 103);
