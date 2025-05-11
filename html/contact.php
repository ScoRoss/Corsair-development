<?php include 'template/header.php'; ?>
<h2>Contact</h2>
<form method="POST" action="contact.php">
  <input type="text" name="name" placeholder="Your Name" required><br>
  <input type="email" name="email" placeholder="Your Email" required><br>
  <textarea name="message" placeholder="Your Message" required></textarea><br>
  <button type="submit">Send</button>
</form>
<?php
if ($_SERVER["REQUEST_METHOD"] == "POST") {
  echo "<p>Message sent! (not really, this is a placeholder)</p>";
}
?>
<?php include 'template/footer.php'; ?>