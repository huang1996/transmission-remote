/**
 * Host-side (Node.js) stand-in for the `Base64Helper` part of `@ohos.util`.
 *
 * Implemented on top of Node.js `Buffer`. TextEncoder/TextDecoder are
 * deliberately NOT declared here: Node.js already provides them, and pulling
 * in DOM-flavoured types would go against the ES2021-only lib used by the
 * build (ArkTS has no DOM).
 */

export class Base64Helper {
  constructor();
  encodeToString(src: Uint8Array): string;
  decodeSync(src: string | Uint8Array): Uint8Array;
}

/**
 * The real HarmonyOS module is consumed as `import { util } from '@ohos.util'`.
 * The namespace alias keeps that style working too.
 */
export namespace util {
  export { Base64Helper };
}
