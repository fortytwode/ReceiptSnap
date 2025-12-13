const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const { Resend } = require("resend");

// Define parameters for Resend configuration
const resendApiKey = defineString("RESEND_API_KEY");

/**
 * Cloud Function to send expense report via email
 *
 * Expects data: {
 *   recipientEmail: string,
 *   reportTitle: string,
 *   bodyText: string,
 *   bodyHtml: string (optional),
 *   csvBase64: string (base64 encoded CSV content),
 *   csvFilename: string (optional, defaults to 'expense_report.csv')
 * }
 */
exports.sendExpenseReport = onCall(async (request) => {
  const data = request.data;

  // Get Resend API key
  const apiKey = resendApiKey.value();

  if (!apiKey || apiKey === "") {
    throw new HttpsError(
      "failed-precondition",
      "Resend API key not configured. Set RESEND_API_KEY in Firebase."
    );
  }

  // Validate required fields
  if (!data.recipientEmail) {
    throw new HttpsError("invalid-argument", "recipientEmail is required");
  }

  if (!data.reportTitle) {
    throw new HttpsError("invalid-argument", "reportTitle is required");
  }

  if (!data.bodyText) {
    throw new HttpsError("invalid-argument", "bodyText is required");
  }

  // Set up Resend
  const resend = new Resend(apiKey);

  // Log the recipient for debugging
  console.log(`Attempting to send email to: "${data.recipientEmail}"`);
  console.log(`Report title: "${data.reportTitle}"`);

  // Build the email - using verified domain for production
  const emailData = {
    from: "ReceiptSnap <noreply@rocketshiphq.com>",
    to: [data.recipientEmail.trim().toLowerCase()],
    subject: `Expense Report: ${data.reportTitle}`,
    text: data.bodyText,
    html: data.bodyHtml || data.bodyText.replace(/\n/g, "<br>"),
  };

  // Add CSV attachment if provided
  if (data.csvBase64) {
    emailData.attachments = [
      {
        content: data.csvBase64,
        filename: data.csvFilename || "expense_report.csv",
      },
    ];
  }

  try {
    const result = await resend.emails.send(emailData);

    if (result.error) {
      console.error("Resend error:", result.error);
      throw new HttpsError("internal", `Failed to send email: ${result.error.message}`);
    }

    console.log(`Email sent successfully to ${data.recipientEmail}`, result);
    return {
      success: true,
      message: `Email sent to ${data.recipientEmail}`,
      id: result.data?.id,
    };
  } catch (error) {
    console.error("Resend error:", error);
    throw new HttpsError(
      "internal",
      `Failed to send email: ${error.message}`
    );
  }
});
