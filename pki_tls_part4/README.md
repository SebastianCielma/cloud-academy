# PKI & TLS — Part 4: CA Rotation, Trust Migration & Production PKI Troubleshooting

## Overview
Kontrolowana rotacja Intermediate CA (`v1 -> v2`) pod wspólnym Root CA, migracja zaufania bez przestoju (oraz demonstracja błędnej kolejności), test czasowego zaufania dual-root, reakcja na kompromitację klucza Intermediate CA, 8 scenariuszy *Certificate Troubleshooting*, diagnostyka błędów `cert-manager`, pełny *Certificate Inventory* oraz analiza i naprawa incydentu produkcyjnego z 02:15.

## Architecture
- **PKI (`pki/scripts/setup-pki.sh`)**: `Root CA v1`, `Root CA v2` (test dual-root), `Intermediate CA v1`, `Intermediate CA v2` (oba pod `Root CA v1`).
- **Services (`infra/docker-compose.yml`)**:
  - `payment-service` (`:8441`) — HTTPS + **mTLS** (`ssl_verify_client on`)
  - `order-service` (`:8442`) — HTTPS
  - `inventory-service` (`:8443`) — HTTPS

## Quickstart & Verification
```bash
make up        # Bootstrap PKI (Root/Int v1 & v2) and start 3 Nginx services
make evidence  # Run all scenarios and generate 6 audit logs in evidence/
make verify    # Run strict regression assertions on evidence/*
make clean     # Stop containers and remove ephemeral .local/ artifacts
```

## Evidence Artifacts
| File | Scope |
| :--- | :--- |
| `evidence/01-ca-rotation-and-migration.log` | Rotacja Intermediate CA v1 -> v2, błędna vs poprawna kolejność migracji zaufania, test Dual-Root (Root v1 + Root v2) |
| `evidence/02-ca-compromise.log` | Reakcja na kompromitację Intermediate CA v1: kwarantanna klucza, identyfikacja certyfikatów, CRL na Root CA v1, weryfikacja odrzucenia (`certificate revoked`) |
| `evidence/03-troubleshooting-8-cases.log` | 8 przypadków (diagnoza -> naprawa bez wyłączania TLS): expired, wrong SAN, incomplete chain, unknown CA, wrong EKU, private key mismatch, protocol mismatch, wrong trust store |
| `evidence/04-cert-manager-failures.log` | Diagnostyka i klasyfikacja warstw błędów `cert-manager` (CA, cert-manager, Kubernetes/DNS/RBAC, aplikacja) |
| `evidence/05-certificate-inventory.md` | Pełne zestawienie certyfikatów: lokalizacja, właściciel, Subject, Issuer, Serial, SAN, NotBefore, NotAfter |
| `evidence/06-final-incident-0215.log` | Symulacja, zbieranie dowodów, RCA i naprawa incydentu produkcyjnego 02:15 (niekompletny chain + niespójne trust stores) bez wyłączania walidacji TLS |

## Additional Questions (Q&A)

1. **Dlaczego rotacja CA jest trudniejsza niż leaf certificate?**
   Wymiana certyfikatu leaf dotyczy pojedynczej usługi, a klienci nadal ufają temu samemu CA. Rotacja CA zmienia korzeń lub ogniwo łańcucha zaufania, co wymaga skoordynowanej aktualizacji *trust stores* we wszystkich klientach, usługach i systemach przed wycofaniem starego CA.
2. **Czym różni się wymiana Intermediate CA od Root CA?**
   **Intermediate CA** może zostać wymienione pod tym samym **Root CA** — jeśli serwery wysyłają pełny łańcuch (`fullchain`), klienci ufający Root CA automatycznie zaufają nowemu Intermediate CA. Wymiana **Root CA** wymaga dystrybucji nowego certyfikatu do *trust stores* wszystkich klientów (OS, JVM, kontenery, przeglądarki, Ingress/mTLS).
3. **Dlaczego podczas migracji może być potrzebne zaufanie do dwóch CA?**
   Ponieważ usług i klientów nie da się przełączyć atomowo w jednej milisekundzie. Okno przejściowe z *dual trust bundle* (stare + nowe CA) pozwala na równoczesne działanie certyfikatów ze starego i nowego CA bez przestoju.
4. **Co się stanie, gdy nowe CA zostanie użyte przed aktualizacją trust stores?**
   Klienci ze starym *trust store* odrzucą handshake TLS/mTLS błędem `unable to get local issuer certificate` / `unknown authority`, co prowadzi do natychmiastowej awarii komunikacji.
5. **Dlaczego kompromitacja CA ma duży blast radius?**
   Przejęcie klucza prywatnego CA pozwala atakującemu wystawiać dowolne, kryptograficznie poprawne certyfikaty (dla dowolnych domen i tożsamości mTLS), którym automatycznie ufają wszystkie systemy akceptujące to CA — zwykłe odnowienie certyfikatów leaf nie usuwa tego zagrożenia.
6. **Czy CRL i OCSP rozwiązują każdy problem po wycieku klucza CA?**
   Nie. Wiele klientów i bibliotek nie sprawdza CRL/OCSP domyślnie, stosuje tryb *soft-fail* przy niedostępności serwera lub korzysta z przestarzałego cache’u. Po kompromitacji CA kluczowe jest również usunięcie skompromitowanego CA z *trust stores* i wymiana łańcucha.
7. **Co zrobić, gdy cert-manager odnowił certyfikat, ale aplikacja używa starego?**
   `cert-manager` aktualizuje jedynie obiekt Kubernetes `Secret`. Jeśli aplikacja nie obsługuje *hot-reload* plików z wolumenu, należy wymusić przeładowanie (np. `SIGHUP`, `kubectl rollout restart`) lub wdrożyć kontroler typu **Stakater Reloader**.
8. **Jak monitorować daty ważności?**
   Przez metryki Prometheusa z `cert-manager` (`certmanager_certificate_expiration_timestamp_seconds`), sondy `blackbox_exporter` (`probe_ssl_earliest_cert_expiry`) oraz cykliczne audyty/alerty (np. progi 30d / 14d / 7d).
9. **Jak planować rotację bez downtime?**
   Stosować fazowaną kolejność: (1) dystrybucja nowego CA do *trust stores* (dual-trust), (2) weryfikacja pokrycia, (3) wydanie nowych certyfikatów, (4) stopniowa podmiana i graceful reload usług, (5) walidacja TLS/mTLS, (6) usunięcie starego CA z *trust stores* dopiero po wygaśnięciu/wymianie wszystkich starych certyfikatów.
10. **Jak zabezpieczyć backup klucza CA?**
    Klucz Root CA powinien być przechowywany *offline* (air-gapped) lub w **HSM/KMS**, z silnym szyfrowaniem, kontrolą dostępu M-of-N (np. Shamir’s Secret Sharing / podział ról), w odseparowanej fizycznie lokalizacji oraz z okresowym testem odtwarzania.
11. **Które elementy lokalnego środowiska nie są production-ready?**
    Klucze Root CA i Intermediate CA są generowane i trzymane lokalnie na dysku w `.local/` bez HSM/KMS i bez separacji offline dla Root CA, CRL jest plikiem lokalnym bez wysoce dostępnego endpointu HTTP/OCSP, a konfiguracja działa na pojedynczym hoście Docker Compose z lokalnymi domenami `.internal.test`.
