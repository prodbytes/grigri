// Made-up App Store certificate chains for the tests, made with openssl in a
// temporary directory (no key is ever committed): a root, an intermediate
// and a leaf shaped like Apple's (its OIDs on the leaf and intermediate),
// plus broken variants. The production verifier trusts Apple Root CA - G3
// only; the tests hand theirs this chain's root.
import { execFileSync } from 'node:child_process';
import { X509Certificate, createPrivateKey, sign } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CONFIG = `
[req]
distinguished_name = dn
[dn]
[v3_ca]
basicConstraints = critical,CA:true
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[v3_int]
basicConstraints = critical,CA:true,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
1.2.840.113635.100.6.2.1 = ASN1:NULL
[v3_int_no_oid]
basicConstraints = critical,CA:true,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
[v3_int_not_ca]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
1.2.840.113635.100.6.2.1 = ASN1:NULL
[v3_leaf]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
1.2.840.113635.100.6.11.1 = ASN1:NULL
[v3_leaf_no_oid]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
`;

/** A certificate (base64 DER, as x5c carries it) and its key (PEM). */
export interface Issued {
  der: string;
  cert: X509Certificate;
  key: string;
}

export interface Chains {
  root: Issued;
  intermediate: Issued;
  leaf: Issued;
  /** Same names, another key: a root nobody trusts. */
  evilRoot: Issued;
  evilIntermediate: Issued;
  evilLeaf: Issued;
  leafNoOid: Issued;
  intermediateNoOid: Issued;
  leafUnderNoOid: Issued;
  intermediateNotCa: Issued;
  leafUnderNotCa: Issued;
  /** A P-384 leaf: Apple's leaves are P-256. */
  leaf384: Issued;
  /** A leaf the root signed itself (no intermediate). */
  leafFromRoot: Issued;
}

export function makeChains(): Chains {
  const dir = mkdtempSync(join(tmpdir(), 'grigri-apple-'));
  try {
    const cnf = join(dir, 'openssl.cnf');
    writeFileSync(cnf, CONFIG);
    const ssl = (...args: string[]) => execFileSync('openssl', args, { cwd: dir, stdio: ['ignore', 'pipe', 'pipe'] });
    const key = (name: string, curve = 'prime256v1') => {
      ssl('ecparam', '-name', curve, '-genkey', '-noout', '-out', `${name}.key`);
      // PKCS#8, which node:crypto reads whatever openssl wrote.
      ssl('pkcs8', '-topk8', '-nocrypt', '-in', `${name}.key`, '-out', `${name}.p8`);
    };
    const read = (name: string): Issued => {
      const pem = readFileSync(join(dir, `${name}.pem`), 'utf8');
      const cert = new X509Certificate(pem);
      return { der: cert.raw.toString('base64'), cert, key: readFileSync(join(dir, `${name}.p8`), 'utf8') };
    };
    const root = (name: string, cn: string) => {
      key(name, 'secp384r1');
      ssl('req', '-new', '-x509', '-config', cnf, '-extensions', 'v3_ca', '-key', `${name}.key`, '-out', `${name}.pem`,
        '-days', '7300', '-subj', `/CN=${cn}/O=Test Fruit Co./C=US`, '-sha384');
      return read(name);
    };
    const issue = (name: string, cn: string, issuer: string, ext: string, curve = 'prime256v1') => {
      key(name, curve);
      ssl('req', '-new', '-config', cnf, '-key', `${name}.key`, '-out', `${name}.csr`, '-subj', `/CN=${cn}/O=Test Fruit Co./C=US`);
      ssl('x509', '-req', '-in', `${name}.csr`, '-CA', `${issuer}.pem`, '-CAkey', `${issuer}.key`, '-set_serial', String(Math.floor(Math.random() * 1e9)),
        '-out', `${name}.pem`, '-days', '3650', '-extfile', cnf, '-extensions', ext, '-sha384');
      return read(name);
    };
    const chains: Chains = {
      root: root('root', 'Test Root CA - G3'),
      intermediate: issue('int', 'Test Worldwide Developer Relations', 'root', 'v3_int'),
      leaf: issue('leaf', 'Test Store Signing', 'int', 'v3_leaf'),
      evilRoot: root('evilroot', 'Test Root CA - G3'),
      evilIntermediate: issue('evilint', 'Test Worldwide Developer Relations', 'evilroot', 'v3_int'),
      evilLeaf: issue('evilleaf', 'Test Store Signing', 'evilint', 'v3_leaf'),
      leafNoOid: issue('leafnooid', 'Test Store Signing', 'int', 'v3_leaf_no_oid'),
      intermediateNoOid: issue('intnooid', 'Test Plain Intermediate', 'root', 'v3_int_no_oid'),
      leafUnderNoOid: issue('leafundernooid', 'Test Store Signing', 'intnooid', 'v3_leaf'),
      intermediateNotCa: issue('intnotca', 'Test Not A CA', 'root', 'v3_int_not_ca'),
      leafUnderNotCa: issue('leafundernotca', 'Test Store Signing', 'intnotca', 'v3_leaf'),
      leaf384: issue('leaf384', 'Test Store Signing', 'int', 'v3_leaf', 'secp384r1'),
      leafFromRoot: issue('leaffromroot', 'Test Store Signing', 'root', 'v3_leaf'),
    };
    return chains;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const b64url = (v: unknown) => Buffer.from(JSON.stringify(v)).toString('base64url');

/** A compact JWS of `payload`, ES256 by `signer`, with `x5c` (and any header overrides). */
export function jws(
  payload: Record<string, unknown>,
  signer: Issued,
  x5c: Issued[],
  header: Record<string, unknown> = {},
): string {
  const h = b64url({ alg: 'ES256', x5c: x5c.map((c) => c.der), ...header });
  const p = b64url(payload);
  const sig = sign('sha256', Buffer.from(`${h}.${p}`), { key: createPrivateKey(signer.key), dsaEncoding: 'ieee-p1363' });
  return `${h}.${p}.${sig.toString('base64url')}`;
}
