// SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only
// Copyright (c) TransmissionRemote contributors
// See LICENSE for the full text and for the provenance of generated files.

/**
 * Tests for the SDK's error model.
 *
 * Two numbering schemes exist on the wire, and the legacy dialect has no codes
 * at all, so the phrase-to-code heuristics are behaviour that callers depend on
 * and are therefore pinned down here.
 *
 * @since 1.0.0
 */

import { describe, it, expect } from '@ohos/hypium';
import {
  RpcErrorCode,
  rpcErrorCodeFromMessage,
  rpcErrorMessage,
  TransmissionError,
  TransmissionErrorKind,
} from '../../main/ets/error/TransmissionError';
import { JsonObject } from '../../main/ets/util/Json';

export default function transmissionErrorTest(): void {
  describe('RpcErrorCode', () => {
    it('uses the JSON-RPC reserved codes', () => {
      expect(RpcErrorCode.PARSE_ERROR).assertEqual(-32700);
      expect(RpcErrorCode.INVALID_REQUEST).assertEqual(-32600);
      expect(RpcErrorCode.METHOD_NOT_FOUND).assertEqual(-32601);
      expect(RpcErrorCode.INVALID_PARAMS).assertEqual(-32602);
      expect(RpcErrorCode.INTERNAL_ERROR).assertEqual(-32603);
    });

    it('uses Transmission-specific codes from 1 upwards', () => {
      expect(RpcErrorCode.SUCCESS).assertEqual(0);
      expect(RpcErrorCode.SET_ANNOUNCE_LIST).assertEqual(1);
      expect(RpcErrorCode.INVALID_TRACKER_LIST).assertEqual(2);
      expect(RpcErrorCode.PATH_NOT_ABSOLUTE).assertEqual(3);
      expect(RpcErrorCode.UNRECOGNIZED_INFO).assertEqual(4);
      expect(RpcErrorCode.SYSTEM_ERROR).assertEqual(5);
      expect(RpcErrorCode.FILE_IDX_OOR).assertEqual(6);
      expect(RpcErrorCode.PIECE_IDX_OOR).assertEqual(7);
      expect(RpcErrorCode.HTTP_ERROR).assertEqual(8);
      expect(RpcErrorCode.CORRUPT_TORRENT).assertEqual(9);
      expect(RpcErrorCode.INVALID_BLOCKLIST_DATA).assertEqual(10);
    });

    it('describes every code', () => {
      expect(rpcErrorMessage(RpcErrorCode.METHOD_NOT_FOUND)).assertEqual('Method not found');
      expect(rpcErrorMessage(RpcErrorCode.PATH_NOT_ABSOLUTE)).assertEqual('path is not absolute');
      expect(rpcErrorMessage(RpcErrorCode.CORRUPT_TORRENT)).assertEqual('invalid or corrupt torrent file');
      expect(rpcErrorMessage(RpcErrorCode.UNKNOWN)).assertEqual('unknown error');
    });
  });

  describe('Legacy error phrase mapping', () => {
    it('recognises the phrases Transmission uses', () => {
      expect(rpcErrorCodeFromMessage('no method name')).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
      // Transmission 4.0.x says "method name not recognized" for an unknown
      // method, while 4.1.0's compatibility layer says "no method name". Both
      // have to map to the same code, because that code is what triggers the
      // automatic downgrade.
      expect(rpcErrorCodeFromMessage('method name not recognized')).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
      expect(rpcErrorCodeFromMessage('Method name not recognized')).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
      expect(rpcErrorCodeFromMessage("Couldn't test port: No Response (0)")).assertEqual(RpcErrorCode.HTTP_ERROR);
      expect(rpcErrorCodeFromMessage('invalid or corrupt torrent file')).assertEqual(RpcErrorCode.CORRUPT_TORRENT);
      expect(rpcErrorCodeFromMessage('file index out of range')).assertEqual(RpcErrorCode.FILE_IDX_OOR);
      expect(rpcErrorCodeFromMessage('path is not absolute')).assertEqual(RpcErrorCode.PATH_NOT_ABSOLUTE);
      expect(rpcErrorCodeFromMessage('no location')).assertEqual(RpcErrorCode.INVALID_PARAMS);
    });

    it('is case insensitive', () => {
      expect(rpcErrorCodeFromMessage('NO METHOD NAME')).assertEqual(RpcErrorCode.METHOD_NOT_FOUND);
    });

    it('reports success and unknown messages distinctly', () => {
      expect(rpcErrorCodeFromMessage('success')).assertEqual(RpcErrorCode.SUCCESS);
      expect(rpcErrorCodeFromMessage('something entirely unexpected')).assertEqual(RpcErrorCode.UNKNOWN);
    });
  });

  describe('TransmissionError', () => {
    it('carries every detail supplied by the caller', () => {
      const data: JsonObject = {};
      data['ip_protocol'] = 'ipv6';
      const error = TransmissionError.rpc(RpcErrorCode.HTTP_ERROR, 'HTTP error from backend service', {
        rawCode: 8,
        httpStatus: 200,
        data: data,
        detail: "Couldn't test port",
        request: 'port_test http://host/rpc',
      });
      expect(error.kind).assertEqual(TransmissionErrorKind.RPC);
      expect(error.rpcCode).assertEqual(RpcErrorCode.HTTP_ERROR);
      expect(error.rawCode).assertEqual(8);
      expect(error.httpStatus).assertEqual(200);
      expect(error.detail).assertEqual("Couldn't test port");
      expect(error.request).assertEqual('port_test http://host/rpc');
      expect(error.data === undefined).assertFalse();
      expect(error.name).assertEqual('TransmissionError');
    });

    it('is an Error subclass so existing error handling keeps working', () => {
      const error = TransmissionError.protocol('bad payload');
      expect(error instanceof Error).assertTrue();
      expect(error instanceof TransmissionError).assertTrue();
    });

    it('combines the base message with the server detail', () => {
      const withDetail = TransmissionError.rpc(RpcErrorCode.HTTP_ERROR, 'HTTP error from backend service', {
        detail: "Couldn't test port",
      });
      expect(withDetail.fullMessage).assertEqual("HTTP error from backend service: Couldn't test port");

      const withoutDetail = TransmissionError.protocol('bad payload');
      expect(withoutDetail.fullMessage).assertEqual('bad payload');

      const duplicated = TransmissionError.rpc(RpcErrorCode.SYSTEM_ERROR, 'system error', { detail: 'system error' });
      expect(duplicated.fullMessage).assertEqual('system error');
    });

    it('marks only genuinely retryable failures as retryable', () => {
      expect(TransmissionError.transport('socket closed').retryable).assertTrue();
      expect(TransmissionError.timeout('too slow').retryable).assertTrue();
      expect(TransmissionError.http('bad gateway', 502).retryable).assertTrue();
      expect(TransmissionError.http('service unavailable', 503).retryable).assertTrue();
      expect(TransmissionError.http('teapot', 418).retryable).assertFalse();
      expect(TransmissionError.authentication('nope', 401).retryable).assertFalse();
      expect(TransmissionError.rpc(RpcErrorCode.INVALID_PARAMS, 'bad params').retryable).assertFalse();
    });

    it('builds unsupported-feature messages the user can act on', () => {
      const error = TransmissionError.unsupported('sequential_download_from_piece', '6.0.0', '4.0.0');
      expect(error.kind).assertEqual(TransmissionErrorKind.UNSUPPORTED);
      expect(error.message).assertContain('6.0.0');
      expect(error.message).assertContain('4.0.0');
    });

    it('builds configuration errors', () => {
      const error = TransmissionError.configuration('the RPC url must not be empty');
      expect(error.kind).assertEqual(TransmissionErrorKind.CONFIGURATION);
      expect(error.retryable).assertFalse();
    });

    it('keeps the wrap of an underlying platform error', () => {
      const cause = new Error('ECONNREFUSED');
      const error = TransmissionError.transport('cannot connect', 'POST http://host/rpc', cause);
      expect(error.cause === undefined).assertFalse();
      if (error.cause !== undefined) {
        expect(error.cause.message).assertEqual('ECONNREFUSED');
      }
    });
  });
}
