const mysql = require("mysql2");

const db = mysql.createConnection({
  host: "localhost",
  user: "root",        // change if your MySQL user is different
  password: "backtocontroversial",        // add your MySQL password here
  database: "seating_allocation",
});

db.connect((err) => {
  if (err) {
    console.error("❌ MySQL connection failed:", err.message);
    process.exit(1);
  }
  console.log("✅ Connected to MySQL — seating_allocation database");
});

module.exports = db;
