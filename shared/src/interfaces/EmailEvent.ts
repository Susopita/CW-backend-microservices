export interface EmailRequest {
    to: string;
    subject: string;
    htmlContent: string;
}

export interface EmailResponse {
    statusCode: number;
    body: string;
}