#!/usr/bin/env python3
"""Check tracked git history for common credential signatures without printing secret values."""
import re, subprocess, sys
rules = {
    "private-key": re.compile(rb"-----BEGIN (?:OPENSSH |RSA |EC |DSA |PGP )?PRIVATE KEY-----"),
    "aws-access-key": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "github-token": re.compile(rb"(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{25,}"),
    "github-fine-grained-token": re.compile(rb"github_pat_[A-Za-z0-9_]{30,}"),
    "slack-token": re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}"),
    "generic-credential-assignment": re.compile(rb"(?im)^\s*(?:password|passwd|secret_key|api_key|access_token|client_secret)\s*[:=]\s*['\"]?([^\s\$\{\}][^\s'\"#]{11,})"),
}
listing=subprocess.check_output(["git","rev-list","--objects","--all"],text=True)
found=[]
seen=set()
count=0
for line in listing.splitlines():
    sha,_,path=line.partition(" ")
    if not path or sha in seen:
        continue
    seen.add(sha)
    typ=subprocess.run(["git","cat-file","-t",sha],capture_output=True,text=True).stdout.strip()
    if typ!="blob": continue
    size=int(subprocess.check_output(["git","cat-file","-s",sha],text=True).strip())
    if size>5_000_000:continue
    body=subprocess.check_output(["git","cat-file","blob",sha])
    if b"\x00" in body[:2048]:continue
    count+=1
    for name,pattern in rules.items():
        if pattern.search(body):
            found.append((name,path,sha[:12]))
print(f"objects_scanned={count}; signatures_found={len(found)}")
for name,path,sha in found:
    print(f"::warning title=Possible credential signature::{name} in {path} (git object {sha}); value intentionally redacted")
if found:
    print("Review the flagged objects and rotate any genuine exposed credentials. History remains accessible even if files are removed.")
    sys.exit(2)
print("No matching high-confidence credential signatures in checked Git objects. This is not an exhaustive secret audit.")
