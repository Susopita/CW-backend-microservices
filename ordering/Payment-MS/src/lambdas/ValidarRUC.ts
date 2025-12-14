import { Handler } from "aws-lambda";

export const validateRuc: Handler = async (event) => {
    console.log("Validando RUC:", event.ruc);
    const ruc = String(event.ruc);

    // Lógica real: RUC debe tener 11 dígitos y empezar con 10 o 20
    const isValidFormat = /^(10|20)\d{9}$/.test(ruc);

    // Simulación: Si termina en '0', decimos que no es válido (habido/hallado)
    const isActive = !ruc.endsWith('0');

    return {
        valido: isValidFormat && isActive,
        razonSocial: isValidFormat ? "EMPRESA DE PRUEBA S.A.C." : null
    };
};