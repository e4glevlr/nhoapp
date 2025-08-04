
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });

admin.initializeApp();

exports.chatProxy = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    // Chỉ cho phép phương thức POST
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    // Lấy ID Token từ Authorization header
    const authorization = req.headers.authorization;
    if (!authorization || !authorization.startsWith("Bearer ")) {
      console.error("No Firebase ID token was passed as a Bearer token in the Authorization header.");
      return res.status(403).send("Unauthorized");
    }

    const idToken = authorization.split("Bearer ")[1];

    try {
      // Xác thực ID Token
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      console.log("ID Token correctly decoded:", decodedToken);

      // Lấy text từ body của yêu cầu
      const { text } = req.body;
      if (!text) {
        return res.status(400).send("Bad Request: Missing 'text' in body");
      }

      // Dữ liệu để gửi đến API bên ngoài
      const postData = {
        user_id: "user123",
        session_id: "session123",
        text: text,
      };

      // Gọi đến API bên ngoài
      const externalApiResponse = await axios.post(
        "https://aitools.ptit.edu.vn/nho/chat",
        postData
      );

      // Chuyển tiếp phản hồi từ API bên ngoài về cho client
      res.status(externalApiResponse.status).send(externalApiResponse.data);

    } catch (error) {
      if (error.code === 'auth/id-token-expired') {
        console.error("Firebase ID token has expired. Get a fresh one.");
        return res.status(403).send("Unauthorized");
      } else if (error.response) {
        // Lỗi từ API bên ngoài
        console.error('Error from external API:', error.response.data);
        return res.status(error.response.status).send(error.response.data);
      } else {
        // Các lỗi khác (ví dụ: xác thực thất bại, lỗi mạng...)
        console.error("Error while verifying Firebase ID token or calling external API:", error);
        return res.status(500).send("Internal Server Error");
      }
    }
  });
});
