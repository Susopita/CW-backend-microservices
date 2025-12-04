import { Handler } from 'aws-lambda';
import { EmailRequest, EmailResponse } from '@cw/shared';

export const handler: Handler<EmailRequest, EmailResponse> = async (event) => {
  const { to, subject, htmlContent } = event;

  const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
  const FROM_EMAIL = process.env.FROM_EMAIL || 'notificaciones@chinawok.com';

  if (!SENDGRID_API_KEY) {
    console.error('SENDGRID_API_KEY no está configurada');
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'SENDGRID_API_KEY no configurada',
        message: 'Error de configuración del servicio de email'
      })
    };
  }

  const payload = {
    personalizations: [
      {
        to: [{ email: to }],
        subject: subject
      }
    ],
    from: { email: FROM_EMAIL },
    content: [
      {
        type: 'text/html',
        value: htmlContent
      }
    ]
  };

  try {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Error de SendGrid:', errorText);

      return {
        statusCode: response.status,
        body: JSON.stringify({
          error: 'Error al enviar email',
          details: errorText
        })
      };
    }

    console.log(`Email enviado exitosamente a ${to}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Email enviado exitosamente',
        to: to
      })
    };

  } catch (error) {
    console.error('Error al enviar email:', error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: 'Error interno al enviar email',
        message: error instanceof Error ? error.message : 'Error desconocido'
      })
    };
  }
};
