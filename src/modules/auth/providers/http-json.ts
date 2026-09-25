import type { SmsProvider } from "./sms.js";

function envFor(
  prefix: string,
  country: string,
): string {
  return (
    process.env[
      `${prefix}_${country}`
    ] ?? ""
  ).trim();
}

function renderTemplate(
  template: string,
  values: Record<string, string>,
): string {
  return template.replace(
    /\{(phone|code|message|locale|country)\}/g,
    (_, key: string) =>
      values[key] ?? "",
  );
}

export class CountryHttpSmsProvider
  implements SmsProvider {
  readonly name: string;

  constructor(
    private readonly country: string,
  ) {
    this.name = `http-json:${country}`;
  }

  async sendOtp(input: {
    phone: string;
    code: string;
    locale?: string;
  }): Promise<{
    success: boolean;
    providerMessageId?: string;
  }> {
    const url = envFor(
      "SMS_API_URL",
      this.country,
    );

    const bodyTemplate =
      envFor(
        "SMS_BODY_TEMPLATE",
        this.country,
      ) ||
      '{"to":"{phone}","message":"{message}"}';

    if (!url) {
      throw new Error(
        `SMS_API_URL_${this.country}_NOT_CONFIGURED`,
      );
    }

    const messageTemplate =
      envFor(
        "SMS_MESSAGE_TEMPLATE",
        this.country,
      ) ||
      "DADIA verification code: {code}";

    const message =
      renderTemplate(
        messageTemplate,
        {
          phone: input.phone,
          code: input.code,
          locale:
              input.locale ?? "en",
          country: this.country,
        },
      );

    const bodyText =
      renderTemplate(
        bodyTemplate,
        {
          phone: input.phone,
          code: input.code,
          message,
          locale:
              input.locale ?? "en",
          country: this.country,
        },
      );

    let body: unknown;

    try {
      body = JSON.parse(bodyText);
    } catch {
      throw new Error(
        `SMS_BODY_TEMPLATE_${this.country}_INVALID_JSON`,
      );
    }

    const apiKey =
      envFor(
        "SMS_API_KEY",
        this.country,
      );

    const headerName =
      envFor(
        "SMS_API_KEY_HEADER",
        this.country,
      ) || "Authorization";

    const authPrefix =
      envFor(
        "SMS_API_KEY_PREFIX",
        this.country,
      );

    const headers: Record<string, string> = {
      "Content-Type":
          "application/json",
      Accept:
          "application/json",
    };

    if (apiKey) {
      headers[headerName] =
          authPrefix
              ? `${authPrefix} ${apiKey}`
              : apiKey;
    }

    const response =
        await fetch(
      url,
      {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      },
    );

    const text =
        await response.text();

    let data: any = null;

    try {
      data = text
          ? JSON.parse(text)
          : null;
    } catch {
      data = null;
    }

    if (!response.ok) {
      throw new Error(
        `SMS_PROVIDER_HTTP_${response.status}`,
      );
    }

    const providerMessageId =
        data?.id ??
        data?.messageId ??
        data?.message_id ??
        data?.data?.id;

    return {
      success: true,
      providerMessageId:
          providerMessageId
              ? String(
                  providerMessageId,
                )
              : undefined,
    };
  }
}
