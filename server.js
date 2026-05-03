const express = require("express");
const cors    = require("cors");
const db      = require("./db");

const app  = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────────────────────
// STUDENTS
// ─────────────────────────────────────────────────────────────

// GET all students
app.get("/students", (req, res) => {
  db.query("SELECT * FROM Student ORDER BY student_id", (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// POST add a student
app.post("/students", (req, res) => {
  const { student_id, name, roll_no, branch } = req.body;
  if (!student_id || !name || !roll_no) {
    return res.status(400).json({ error: "student_id, name and roll_no are required" });
  }
  db.query(
    "INSERT INTO Student VALUES (?, ?, ?, ?)",
    [student_id, name, roll_no, branch || "N/A"],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Student added successfully" });
    }
  );
});

// ─────────────────────────────────────────────────────────────
// HALLS
// ─────────────────────────────────────────────────────────────

// GET all halls
app.get("/halls", (req, res) => {
  db.query(
    `SELECT h.*, 
      (SELECT COUNT(*) FROM Allocation a 
       WHERE a.hall_id = h.hall_id) AS total_allocated
     FROM Hall h ORDER BY hall_id`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

// POST add a hall
app.post("/halls", (req, res) => {
  const { hall_id, hall_name, capacity } = req.body;
  if (!hall_id || !hall_name || !capacity) {
    return res.status(400).json({ error: "hall_id, hall_name and capacity are required" });
  }
  db.query(
    "INSERT INTO Hall VALUES (?, ?, ?)",
    [hall_id, hall_name, capacity],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Hall added successfully" });
    }
  );
});

// ─────────────────────────────────────────────────────────────
// EXAMS
// ─────────────────────────────────────────────────────────────

// GET all exams (with course title)
app.get("/exams", (req, res) => {
  db.query(
    `SELECT e.exam_id, e.exam_date, c.title AS course_title, c.dept
     FROM Exam_Schedule e
     JOIN Course c ON e.course_id = c.course_id
     ORDER BY e.exam_date`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

// ─────────────────────────────────────────────────────────────
// ALLOCATIONS
// ─────────────────────────────────────────────────────────────

// GET all allocations (rich join — mirrors print_seating_plan)
app.get("/allocations", (req, res) => {
  db.query(
    `SELECT
        a.alloc_id,
        s.name        AS student_name,
        s.roll_no,
        s.branch,
        h.hall_name,
        a.seat_no,
        c.title       AS course_title,
        DATE_FORMAT(e.exam_date, '%d %b %Y') AS exam_date,
        a.allocation_date
     FROM Allocation a
     JOIN Student      s ON a.student_id = s.student_id
     JOIN Hall         h ON a.hall_id    = h.hall_id
     JOIN Exam_Schedule e ON a.exam_id   = e.exam_id
     JOIN Course       c ON e.course_id  = c.course_id
     ORDER BY h.hall_name, a.seat_no`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

// POST — run the allocate_random_seats stored procedure
app.post("/allocate", (req, res) => {
  const { exam_id } = req.body;
  if (!exam_id) return res.status(400).json({ error: "exam_id is required" });

  // First clear any existing allocation for this exam so it's idempotent
  db.query("DELETE FROM Allocation WHERE exam_id = ?", [exam_id], (delErr) => {
    if (delErr) return res.status(500).json({ error: delErr.message });

    db.query("CALL allocate_random_seats(?)", [exam_id], (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Seats allocated successfully" });
    });
  });
});

// ─────────────────────────────────────────────────────────────
// COURSES
// ─────────────────────────────────────────────────────────────

app.get("/courses", (req, res) => {
  db.query("SELECT * FROM Course ORDER BY course_id", (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

// ─────────────────────────────────────────────────────────────
// ENROLLMENTS
// ─────────────────────────────────────────────────────────────

app.get("/enrollments", (req, res) => {
  db.query(
    `SELECT s.name AS student_name, s.roll_no, c.title AS course_title
     FROM Student_Course sc
     JOIN Student s ON sc.student_id = s.student_id
     JOIN Course  c ON sc.course_id  = c.course_id
     ORDER BY s.name`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

app.post("/enroll", (req, res) => {
  const { student_id, course_id } = req.body;
  if (!student_id || !course_id)
    return res.status(400).json({ error: "student_id and course_id required" });

  db.query(
    "INSERT INTO Student_Course VALUES (?, ?)",
    [student_id, course_id],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: "Student enrolled successfully" });
    }
  );
});

// ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────
app.get("/analytics/piechart", (req, res) => {
  db.query(
    `SELECT h.hall_name, COUNT(a.alloc_id) AS total_students
     FROM Hall h
     LEFT JOIN Allocation a ON h.hall_id = a.hall_id
     GROUP BY h.hall_id, h.hall_name
     ORDER BY h.hall_id`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

// ─────────────────────────────────────────────────────────────
// ANALYTICS — hall occupancy (capacity vs used)
// ─────────────────────────────────────────────────────────────
app.get("/analytics/occupancy", (req, res) => {
  db.query(
    `SELECT h.hall_name, h.capacity,
       COUNT(a.alloc_id) AS occupied,
       h.capacity - COUNT(a.alloc_id) AS available
     FROM Hall h
     LEFT JOIN Allocation a ON h.hall_id = a.hall_id
     GROUP BY h.hall_id, h.hall_name, h.capacity`,
    (err, rows) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(rows);
    }
  );
});

// ─────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});
