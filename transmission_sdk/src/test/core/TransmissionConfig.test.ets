// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the client configuration.
 *
 * Configuration is small, but every field reaches the wire: the URL selects the
 * endpoint, the timeout bounds every request, the mode pins the dialect and the
 * extra headers are merged into each request. `validate()` is the single place
 * that rejects configurations the SDK could not act on.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import { DEFAULT_TIMEOUT_MS, TransmissionConfig } from '../../main/ets/core/TransmissionConfig';
import { ApiStyleMode } from '../../main/ets/compat/ApiStyle';
import { TransmissionError, TransmissionErrorKind } from '../../main/ets/error/TransmissionError';

/** Asserts that `config.validate()` throws a configuration error. */
function expectConfigurationError(config: TransmissionConfig): void {
  try {
    config.validate();
    expect(true).assertFalse();
  } catch (error) {
    expect((error as TransmissionError).kind).assertEqual(TransmissionErrorKind.CONFIGURATION);
  }
}

export default function transmissionConfigTest(): void {
  describe('TransmissionConfig url building', () => {
    it('of() without arguments uses the conventional local endpoint', () => {
      const config = TransmissionConfig.of();
      expect(config.url).assertEqual('http://127.0.0.1:9091/transmission/rpc');
    });

    it('of() keeps an explicit url', () => {
      const config = TransmissionConfig.of('https://seedbox.example:8443/rpc');
      expect(config.url).assertEqual('https://seedbox.example:8443/rpc');
    });

    it('forHost() applies the default port and path', () => {
      const config = TransmissionConfig.forHost('192.168.1.10');
      expect(config.url).assertEqual('http://192.168.1.10:9091/transmission/rpc');
    });

    it('forHost() honours an explicit port and path', () => {
      const config = TransmissionConfig.forHost('nas', 1234, '/custom/rpc');
      expect(config.url).assertEqual('http://nas:1234/custom/rpc');
    });

    it('forHost() inserts a leading slash on a path that lacks one', () => {
      const config = TransmissionConfig.forHost('nas', 9091, 'rpc');
      expect(config.url).assertEqual('http://nas:9091/rpc');
    });
  });

  describe('TransmissionConfig fluent setters', () => {
    it('withUrl() replaces the endpoint', () => {
      const config = TransmissionConfig.of().withUrl('http://other:9091/rpc');
      expect(config.url).assertEqual('http://other:9091/rpc');
    });

    it('withCredentials() stores both halves of the pair', () => {
      const config = TransmissionConfig.of().withCredentials('admin', 'secret');
      expect(config.username).assertEqual('admin');
      expect(config.password).assertEqual('secret');
    });

    it('withApiStyleMode() stores the negotiation strategy', () => {
      const config = TransmissionConfig.of().withApiStyleMode(ApiStyleMode.LEGACY);
      expect(config.apiStyleMode).assertEqual(ApiStyleMode.LEGACY);
    });

    it('withTimeout() stores the millisecond budget', () => {
      const config = TransmissionConfig.of().withTimeout(2500);
      expect(config.timeoutMs).assertEqual(2500);
    });

    it('withSessionId() stores a restored CSRF id', () => {
      const config = TransmissionConfig.of().withSessionId('restored');
      expect(config.sessionId).assertEqual('restored');
    });

    it('withHeader() lower-cases the header name on insert', () => {
      const config = TransmissionConfig.of().withHeader('X-Custom-Header', 'value');
      expect(config.headers.get('x-custom-header')).assertEqual('value');
      expect(config.headers.has('X-Custom-Header')).assertFalse();
    });

    it('starts with sensible defaults', () => {
      const config = TransmissionConfig.of();
      expect(config.apiStyleMode).assertEqual(ApiStyleMode.AUTO);
      expect(config.timeoutMs).assertEqual(DEFAULT_TIMEOUT_MS);
      expect(config.username).assertUndefined();
      expect(config.password).assertUndefined();
      expect(config.sessionId).assertUndefined();
      expect(config.headers.size).assertEqual(0);
    });
  });

  describe('TransmissionConfig validation', () => {
    it('accepts a well-formed configuration', () => {
      TransmissionConfig.of('http://host:9091/rpc')
        .withCredentials('user', 'pass')
        .withTimeout(1000)
        .validate();
      expect(true).assertTrue();
    });

    it('rejects an empty url', () => {
      expectConfigurationError(TransmissionConfig.of(''));
    });

    it('rejects a url that is not http(s)', () => {
      expectConfigurationError(TransmissionConfig.of('ftp://host/rpc'));
    });

    it('rejects a zero timeout', () => {
      expectConfigurationError(TransmissionConfig.of('http://host/rpc').withTimeout(0));
    });

    it('rejects a negative timeout', () => {
      expectConfigurationError(TransmissionConfig.of('http://host/rpc').withTimeout(-5));
    });

    it('rejects a password configured without a username', () => {
      expectConfigurationError(TransmissionConfig.of('http://host/rpc').withCredentials('', 'secret'));
    });
  });
}
