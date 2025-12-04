import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, BatchWriteCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.INVENTORY_TABLE_NAME;

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
        const body = JSON.parse(event.body || "{}");
        const products = body.products;

        if (!Array.isArray(products) || products.length === 0) {
            return { statusCode: 400, body: "Se requiere un array 'products' con datos." };
        }

        // 1. Transformar entrada simple al formato Single Table Design
        const writeRequests = products.map((prod: any) => ({
            PutRequest: {
                Item: {
                    producto_id: `TENANT#${prod.producto_id}`,      // Partition Key
                    tenant_id: `PROD#${prod.tenant_id}`,             // Sort Key
                    tipo_id: prod.tipo_id,      // GSI Key

                    stock: prod.stock,
                    price: prod.price,
                    name: prod.name,
                    description: prod.description || "",
                    img: prod.img || "",

                    updatedAt: new Date().toISOString()
                }
            }
        }));

        // 2. DynamoDB BatchWrite solo acepta 25 items por request.
        //    Hacemos "Chunking" (partir el array en pedazos de 25).
        const chunks = [];
        while (writeRequests.length > 0) {
            chunks.push(writeRequests.splice(0, 25));
        }

        console.log(`Procesando ${products.length} productos en ${chunks.length} lotes...`);

        // 3. Ejecutar escrituras en paralelo
        const promises = chunks.map(chunk =>
            docClient.send(new BatchWriteCommand({
                RequestItems: {
                    [TABLE_NAME!]: chunk
                }
            }))
        );

        await Promise.all(promises);

        return {
            statusCode: 201,
            body: JSON.stringify({
                message: "Carga masiva completada",
                count: products.length,
                batches: chunks.length
            })
        };

    } catch (error) {
        console.error("Error en carga masiva:", error);
        return { statusCode: 500, body: JSON.stringify({ error: "Error interno procesando lote" }) };
    }
};