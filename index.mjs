import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { PutCommand, DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const sesClient = new SESClient({});

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
    
    // Send email
    const emailParams = {
      Destination: {
        ToAddresses: ["huytrannhat.9001@gmail.com"],
      },
      Message: {
        Body: {
          Text: {
            Data: `Hello ${name},\n\nThank you for contacting me! I have received your message: \n\nSubject: ${subject}\nMessage: ${message}\n\nI will get back to you shortly.`,
            Charset: "UTF-8",
          },
        },
        Subject: {
          Data: "Thank you for your message",
          Charset: "UTF-8",
        },
      },
      Source: "huytrannhat.9001@gmail.com",
    };

    const sesCommand = new SendEmailCommand(emailParams);
    await sesClient.send(sesCommand);

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
