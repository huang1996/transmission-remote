// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * HarmonyOS implementation of {@link HttpTransport}.
 *
 * This is the only file in the SDK that touches `@kit.NetworkKit`, which keeps
 * every other module free of platform dependencies and therefore runnable on a
 * plain JavaScript engine for testing.
 *
 * A fresh `http.HttpRequest` is created per call because the NetworkKit request
 * object is not documented as safe for concurrent use; the object is destroyed
 * as soon as the call settles so sockets are never leaked.
 *
 * @since 1.0.0
 */

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AbstractHttpTransport, HttpRequest, HttpResponse, HttpVerb } from '../transport/HttpTransport';
import { TransmissionError } from '../error/TransmissionError';
import { HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON } from '../constants/WireProtocol';

/** NetworkKit error codes worth distinguishing. See `@kit.NetworkKit` docs. */
const ERR_TIMEOUT: number = 2300028;
const ERR_COULDNT_RESOLVE_HOST: number = 2300006;
const ERR_COULDNT_CONNECT: number = 2300007;
const ERR_OPERATION_TIMEDOUT: number = 2300028;

/** {@link HttpTransport} backed by HarmonyOS NetworkKit. */
export class ArkHttpTransport extends AbstractHttpTransport {
  /** Creates a transport. One instance is enough for a whole client. */
  constructor() {
    super();
  }

  execute(request: HttpRequest): Promise<HttpResponse> {
    if (this.isDisposed) {
      return Promise.reject(TransmissionError.transport('the transport has been destroyed', request.description));
    }

    const httpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: request.verb === HttpVerb.GET ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: ArkHttpTransport.toHeaderObject(request),
      extraData: request.body,
      connectTimeout: request.timeoutMs,
      readTimeout: request.timeoutMs,
      expectDataType: http.HttpDataType.STRING,
    };

    return httpRequest
      .request(request.url, options)
      .then((response: http.HttpResponse) => {
        return new HttpResponse(
          Number(response.responseCode),
          ArkHttpTransport.toHeaderMap(response.header),
          typeof response.result === 'string' ? response.result : '',
        );
      })
      .catch((error: BusinessError) => {
        throw ArkHttpTransport.toTransmissionError(error, request.description);
      })
      .finally(() => {
        httpRequest.destroy();
      });
  }

  protected onDestroy(): void {
    // Nothing to release: the NetworkKit request objects are per-call.
  }

  /** Converts the SDK header map into the object NetworkKit expects. */
  private static toHeaderObject(request: HttpRequest): Record<string, string> {
    const header: Record<string, string> = {};
    request.headers.forEach((value: string, key: string) => {
      header[key] = value;
    });
    if (header[HEADER_CONTENT_TYPE] === undefined) {
      header[HEADER_CONTENT_TYPE] = CONTENT_TYPE_JSON;
    }
    return header;
  }

  /**
   * Normalises NetworkKit's `Object`-typed header bag into a lower-cased map.
   *
   * Values may legitimately be a single string or an array of strings, so both
   * shapes are handled.
   */
  private static toHeaderMap(raw: Object | undefined): Map<string, string> {
    const headers = new Map<string, string>();
    if (raw === undefined || raw === null) {
      return headers;
    }
    const bag = raw as Record<string, string | string[]>;
    for (const key of Object.keys(bag)) {
      const value = bag[key];
      if (typeof value === 'string') {
        headers.set(key.toLowerCase(), value);
      } else if (Array.isArray(value) && value.length > 0) {
        headers.set(key.toLowerCase(), value[0]);
      }
    }
    return headers;
  }

  /** Translates a NetworkKit failure into the SDK's error type. */
  private static toTransmissionError(error: BusinessError, request: string): TransmissionError {
    const code = error?.code ?? 0;
    const message = error?.message ?? 'unknown network error';
    if (code === ERR_TIMEOUT || code === ERR_OPERATION_TIMEDOUT) {
      return TransmissionError.timeout(`the request timed out (${message})`, request);
    }
    if (code === ERR_COULDNT_RESOLVE_HOST) {
      return TransmissionError.transport(`cannot resolve the server host (${message})`, request, error);
    }
    if (code === ERR_COULDNT_CONNECT) {
      return TransmissionError.transport(`cannot connect to the server (${message})`, request, error);
    }
    return TransmissionError.transport(message, request, error);
  }
}
