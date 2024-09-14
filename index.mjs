import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

export const handler = async (event, context, callback) => {
  try {
    const requestBody = event;
    const { messageId, name, email, subject, message } = requestBody;

    console.log('Parsed body:', { messageId, name, email, subject, message });

    if (!messageId || !name || !email || !subject || !message) {
      return {
        statusCode: 400,
        body: JSON.stringify({
          message: "Missing required fields: name, email, subject, or message.",
        }),
      };
    }

    const command = new PutCommand({
      TableName: 'ContactMeMessages',
      Item: {
        MessageId: messageId,
        Name: name,
        Email: email,
        Subject: subject,
        Message: message,
        Timestamp: new Date().toISOString(),
      },
    });
    console.log("---a", command)

    await docClient.send(command);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: 'Your message has been sent successfully!',
      }),
    };

  } catch (error) {
    console.error("Error:", error.message);

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: 'An error occurred while sending your message.',
        error: error.message,
      }),
    };
  }
};
