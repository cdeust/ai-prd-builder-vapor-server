# Resilient Proprietary Architecture - AI PRD Builder

## Critical Realization

**Your Current Architecture is Actually Superior for Resilience**

The current approach where the library contains ALL logic means:
- ✅ Works offline (no internet required)
- ✅ Graceful degradation (if backend fails, client still fully functional)
- ✅ No single point of failure (backend can go down, apps keep working)
- ✅ Users own their AI keys (direct to Anthropic/OpenAI)

**The Problem**: Intellectual property protection, NOT resilience.

---

## The Real Challenge

How do we **protect proprietary intelligence** while **maintaining full offline capability**?

### What We're Protecting

1. **Prompt Engineering** - Proprietary prompt templates, chain-of-thought strategies
2. **Orchestration Logic** - Multi-turn reasoning, context optimization
3. **Professional Analysis Algorithms** - Conflict detection, complexity scoring, challenge prediction
4. **RAG Implementation** - Semantic search strategies, embedding optimization
5. **Provider Routing Logic** - Which AI provider for which task, fallback strategies

### What We Need to Preserve

1. **Offline Functionality** - Full PRD generation without internet
2. **User-Owned AI Keys** - Users provide their own Anthropic/OpenAI keys
3. **No Backend Dependency** - Apps work even if backend is down
4. **Direct AI Calls** - Client calls AI providers directly (faster, cheaper)

---

## Solution: Encrypted Library Distribution

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              Client App (iOS/Android/Desktop/Web)           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │  ai-prd-builder Library (ENCRYPTED at rest)          │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  License Manager (validates & decrypts)       │   │  │
│  │  │  - Checks license key                         │   │  │
│  │  │  │  - Validates signature (asymmetric crypto) │   │  │
│  │  │  │  - Decrypts core logic (symmetric crypto)  │   │  │
│  │  │  └─> Loads into memory (runtime only)         │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  Decrypted Core Intelligence (RAM only)       │   │  │
│  │  │  - Prompts ← PROTECTED (encrypted at rest)    │   │  │
│  │  │  - Orchestration ← PROTECTED                  │   │  │
│  │  │  - Analysis Algorithms ← PROTECTED            │   │  │
│  │  │  - ThinkingCore ← PROTECTED                   │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                       ↓                                │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │  AI Provider Adapters (clear, not encrypted)  │   │  │
│  │  │  - User provides their own API keys           │   │  │
│  │  │  - Direct calls to Anthropic/OpenAI/Gemini    │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              ↓
                     Works FULLY offline
                     Backend optional (only for license validation)
```

### Key Innovation: Runtime Decryption

**At Rest**: Proprietary code is encrypted in the binary
**At Runtime**: License key decrypts code into memory, never persists to disk
**Security**: Even with binary access, cannot extract prompts/algorithms without valid license

---

## Technical Implementation

### Step 1: License System

```swift
// LicenseManager.swift (Clear, not encrypted)

public class LicenseManager {
    private static let publicKey = """
    -----BEGIN PUBLIC KEY-----
    [Your RSA-4096 public key]
    -----END PUBLIC KEY-----
    """

    public enum LicenseType {
        case developer(deviceId: String)     // Single device, dev mode
        case personal(userId: String)        // Single user, N devices
        case team(organizationId: String)    // Organization license
        case enterprise(customerId: String)  // Enterprise, custom terms
    }

    public struct License {
        let type: LicenseType
        let expirationDate: Date?
        let decryptionKey: Data  // AES-256 key (encrypted with RSA)
        let signature: Data      // RSA signature of license
    }

    public static func validate(_ licenseKey: String) throws -> License {
        // 1. Decode license (Base64)
        let licenseData = Data(base64Encoded: licenseKey)!

        // 2. Verify RSA signature
        guard verifySignature(licenseData, publicKey: publicKey) else {
            throw LicenseError.invalidSignature
        }

        // 3. Check expiration
        let license = try JSONDecoder().decode(License.self, from: licenseData)
        if let expiration = license.expirationDate, expiration < Date() {
            throw LicenseError.expired
        }

        // 4. Check device/user authorization
        try validateAuthorization(license)

        return license
    }

    private static func validateAuthorization(_ license: License) throws {
        switch license.type {
        case .developer(let deviceId):
            // Check if current device matches
            guard getCurrentDeviceId() == deviceId else {
                throw LicenseError.deviceMismatch
            }

        case .personal(let userId):
            // Check if current user matches (via iCloud, Google account, etc.)
            guard getCurrentUserId() == userId else {
                throw LicenseError.userMismatch
            }

        case .team(let orgId):
            // Verify user belongs to organization (may need online check)
            try verifyOrganizationMembership(orgId)

        case .enterprise(let customerId):
            // Custom validation logic
            try verifyEnterpriseCustomer(customerId)
        }
    }
}
```

### Step 2: Encrypted Library Bundle

```swift
// EncryptedCore.swift (Generated during build)

public class EncryptedCore {
    // These are encrypted at build time
    private static let encryptedPrompts: Data = Data(base64Encoded: """
    [AES-256 encrypted blob of PRDPrompts.swift]
    """)!

    private static let encryptedOrchestration: Data = Data(base64Encoded: """
    [AES-256 encrypted blob of Orchestration logic]
    """)!

    private static let encryptedAnalysis: Data = Data(base64Encoded: """
    [AES-256 encrypted blob of Analysis algorithms]
    """)!

    // Decryption happens at runtime
    public static func loadIntelligence(license: LicenseManager.License) throws -> IntelligenceCore {
        // 1. Decrypt AES key using license
        let aesKey = try decryptAESKey(license.decryptionKey)

        // 2. Decrypt each module
        let promptsCode = try AES.decrypt(encryptedPrompts, key: aesKey)
        let orchestrationCode = try AES.decrypt(encryptedOrchestration, key: aesKey)
        let analysisCode = try AES.decrypt(encryptedAnalysis, key: aesKey)

        // 3. Load into memory (dynamic loading)
        let prompts = try loadModule(promptsCode, as: PRDPrompts.self)
        let orchestrator = try loadModule(orchestrationCode, as: PRDOrchestrator.self)
        let analyzer = try loadModule(analysisCode, as: ProfessionalAnalyzer.self)

        // 4. Return runtime instance
        return IntelligenceCore(
            prompts: prompts,
            orchestrator: orchestrator,
            analyzer: analyzer
        )
    }

    private static func loadModule<T>(_ code: Data, as type: T.Type) throws -> T {
        // Dynamic code loading (platform-specific)
        #if os(iOS) || os(macOS)
        // Use dlopen/dlsym on Apple platforms
        return try loadDylib(code, as: type)
        #elseif os(Android)
        // Use JNI on Android
        return try loadJNI(code, as: type)
        #else
        // Use platform-specific dynamic loading
        fatalError("Platform not supported")
        #endif
    }
}
```

### Step 3: Encrypted Build Process

```bash
#!/bin/bash
# encrypt_library.sh

# 1. Build the library normally
swift build -c release

# 2. Extract proprietary modules
PROPRIETARY_FILES=(
    "Sources/Orchestration/PRDOrchestrator.swift"
    "Sources/PRDGenerator/PRDPrompts.swift"
    "Sources/Analysis/ConflictAnalyzer.swift"
    "Sources/Analysis/ChallengePredictor.swift"
    "Sources/ThinkingCore/ChainOfThought.swift"
    "Sources/ImplementationAnalysis/CodeArchaeologist.swift"
)

# 3. Generate AES-256 key (unique per build)
AES_KEY=$(openssl rand -hex 32)

# 4. Encrypt each proprietary file
for file in "${PROPRIETARY_FILES[@]}"; do
    echo "Encrypting $file..."
    openssl enc -aes-256-cbc -salt \
        -in "$file" \
        -out "${file}.encrypted" \
        -pass "pass:$AES_KEY"
done

# 5. Embed encrypted blobs into EncryptedCore.swift
python generate_encrypted_core.py \
    --aes-key "$AES_KEY" \
    --files "${PROPRIETARY_FILES[@]}" \
    --output "Sources/EncryptedCore.swift"

# 6. Remove clear-text proprietary files from build
for file in "${PROPRIETARY_FILES[@]}"; do
    rm "$file"
done

# 7. Rebuild with encrypted core
swift build -c release

# 8. Sign the binary (code signing)
codesign -s "Developer ID" .build/release/AIPRDBuilder
```

### Step 4: Public API (Clear Code)

```swift
// AIPRDBuilder.swift (Clear, not encrypted - public API)

public class AIPRDBuilder {
    private let intelligence: IntelligenceCore
    private let userProvidedAIKey: String

    public init(
        licenseKey: String,
        anthropicKey: String? = nil,
        openAIKey: String? = nil,
        geminiKey: String? = nil
    ) throws {
        // 1. Validate license
        let license = try LicenseManager.validate(licenseKey)

        // 2. Decrypt and load intelligence
        self.intelligence = try EncryptedCore.loadIntelligence(license: license)

        // 3. Use user's AI keys (not hardcoded)
        if let key = anthropicKey {
            self.userProvidedAIKey = key
        } else if let key = openAIKey {
            self.userProvidedAIKey = key
        } else {
            throw PRDBuilderError.noAIKeyProvided
        }
    }

    public func generatePRD(
        from request: PRDRequest
    ) async throws -> PRDDocument {
        // Uses decrypted intelligence + user's AI key
        return try await intelligence.orchestrator.generatePRD(
            request: request,
            aiProvider: AnthropicProvider(apiKey: userProvidedAIKey),
            prompts: intelligence.prompts,
            analyzer: intelligence.analyzer
        )
    }

    // Works FULLY offline (no backend calls)
}
```

---

## How Users Consume the Library

### iOS App

```swift
// iOS app code
import AIPRDBuilder

class PRDService {
    private let builder: AIPRDBuilder

    init() throws {
        // License key (purchased, validated once online, then cached)
        let licenseKey = UserDefaults.standard.string(forKey: "prd_license_key")!

        // User's own Anthropic key (they pay Anthropic directly)
        let anthropicKey = UserDefaults.standard.string(forKey: "anthropic_api_key")!

        // Initialize (decrypts core intelligence)
        self.builder = try AIPRDBuilder(
            licenseKey: licenseKey,
            anthropicKey: anthropicKey
        )
    }

    func generatePRD(title: String, description: String) async throws -> PRDDocument {
        let request = PRDRequest(title: title, description: description)

        // Works offline! Calls Anthropic directly (user's key)
        return try await builder.generatePRD(from: request)
    }
}
```

### Android App (via Kotlin bridge)

```kotlin
// Android app code
import com.yourcompany.aiprdbuilder.AIPRDBuilder

class PRDService(context: Context) {
    private val builder: AIPRDBuilder

    init {
        val prefs = context.getSharedPreferences("prefs", Context.MODE_PRIVATE)
        val licenseKey = prefs.getString("prd_license_key", null)!!
        val anthropicKey = prefs.getString("anthropic_api_key", null)!!

        builder = AIPRDBuilder(
            licenseKey = licenseKey,
            anthropicKey = anthropicKey
        )
    }

    suspend fun generatePRD(title: String, description: String): PRDDocument {
        val request = PRDRequest(title, description)
        return builder.generatePRD(request)
    }
}
```

### Web App (via WebAssembly)

```typescript
// Web app code
import init, { AIPRDBuilder } from './wasm/ai_prd_builder.js';

async function initPRDBuilder() {
  // Initialize WASM
  await init();

  const licenseKey = localStorage.getItem('prd_license_key')!;
  const anthropicKey = localStorage.getItem('anthropic_api_key')!;

  // Initialize (decrypts core intelligence in WASM)
  const builder = new AIPRDBuilder(licenseKey, anthropicKey);

  return builder;
}

async function generatePRD(title: string, description: string) {
  const builder = await initPRDBuilder();

  // Works in browser! Calls Anthropic directly from client
  return await builder.generatePRD({ title, description });
}
```

---

## Backend Role (Optional, Light)

### What Backend DOES

1. **License Validation** (online check, then cached locally)
2. **License Delivery** (purchase flow)
3. **Usage Analytics** (optional telemetry)
4. **Codebase Indexing** (for RAG, if user wants cloud storage)
5. **Premium Features** (e.g., team collaboration, shared PRDs)

### What Backend DOES NOT

1. ❌ PRD generation (happens in client)
2. ❌ AI orchestration (happens in client)
3. ❌ Professional analysis (happens in client)
4. ❌ Store user AI keys (user stores locally)

### Backend API (Minimal)

```swift
// Vapor Backend - Lightweight

// License validation endpoint (called once per device)
app.post("api", "v1", "licenses", "validate") { req -> LicenseValidationResponse in
    let request = try req.content.decode(ValidateLicenseRequest.self)

    // Verify license with licensing server
    let isValid = try await licensingService.validate(
        licenseKey: request.licenseKey,
        deviceId: request.deviceId,
        userId: request.userId
    )

    return LicenseValidationResponse(valid: isValid, expiresAt: ...)
}

// Optional: Codebase indexing (if user wants cloud RAG)
app.post("api", "v1", "codebases", "index") { req -> CodebaseIndexResponse in
    let request = try req.content.decode(IndexCodebaseRequest.self)

    // Index codebase in cloud (optional feature)
    let indexId = try await codebaseIndexer.index(request.githubUrl)

    return CodebaseIndexResponse(indexId: indexId)
}

// Optional: Team collaboration (premium feature)
app.get("api", "v1", "team", "prds") { req -> [SharedPRD] in
    let user = try req.auth.require(User.self)

    // Fetch team's shared PRDs
    return try await prdRepository.findByTeam(user.teamId)
}
```

---

## Security Analysis

### What This Protects Against

1. **Static Binary Analysis** ✅
   - Proprietary code is encrypted in the binary
   - Tools like `strings`, `otool`, `objdump` show only encrypted blobs

2. **Runtime Memory Dumps** ⚠️
   - Decrypted code exists in RAM (necessary for execution)
   - Mitigation: Code obfuscation, anti-debugging checks, memory encryption

3. **Decompilation** ✅
   - Decompiled code shows encrypted data structures
   - Logic flow is not revealed

4. **Man-in-the-Middle** ✅
   - AI calls go directly from client to Anthropic/OpenAI (HTTPS)
   - No interception opportunity

5. **License Sharing** ✅
   - Licenses tied to device ID or user ID
   - Cannot be shared without detection

### What This Does NOT Protect Against

1. **Determined Reverse Engineering** ⚠️
   - Skilled attacker with debugger can extract from RAM
   - Mitigation: Obfuscation, anti-debugging, legal protection (EULA)

2. **Insider Threat** ❌
   - Developer with source code access
   - Mitigation: Access control, code reviews, non-compete

3. **API Key Leaks** ⚠️
   - User's AI keys (but that's their responsibility)
   - Mitigation: Education, key rotation

---

## Licensing Models

### Model 1: Device License

```
License tied to specific device ID
- iOS: identifierForVendor
- Android: ANDROID_ID
- macOS: Serial number hash
- Web: Browser fingerprint

Pros: Simple, offline-first
Cons: Device change requires reactivation
```

### Model 2: User License

```
License tied to user account (iCloud, Google, email)
- Works across user's devices
- Requires one-time online validation
- Cached locally for offline use

Pros: Multi-device support
Cons: Need online check initially
```

### Model 3: Subscription License

```
Monthly/annual subscription
- License expires after period
- Requires periodic online check (e.g., weekly)
- Grace period for offline use

Pros: Recurring revenue
Cons: Requires regular connectivity
```

### Recommended: Hybrid Model

```swift
public enum LicenseMode {
    case perpetual(deviceId: String)      // One-time purchase, tied to device
    case subscription(userId: String)      // Monthly, tied to user, multi-device
    case enterprise(organizationId: String) // Custom terms
}

// Allow offline for 30 days, then require online check
let gracePeriod: TimeInterval = 30 * 24 * 60 * 60
```

---

## Graceful Degradation Strategy

### Scenario 1: Backend Down (License Already Validated)

```swift
// License cached locally, encrypted core already decrypted
✅ Full functionality (PRD generation, analysis, everything)
✅ AI calls go directly to Anthropic/OpenAI (no backend involved)
✅ User doesn't notice backend is down
```

### Scenario 2: Internet Down (Already Initialized)

```swift
// Everything works offline
✅ PRD generation (uses local intelligence)
✅ AI calls (if cached or using local AI)
⚠️ Cannot fetch new license (but cached license works)
⚠️ Cannot sync shared PRDs (but local generation works)
```

### Scenario 3: License Expired

```swift
// Grace period handling
if licenseExpired && withinGracePeriod {
    ⚠️ Show warning ("License expiring soon")
    ✅ Full functionality
} else if licenseExpired && !withinGracePeriod {
    ❌ Cannot decrypt core intelligence
    ✅ Show renewal prompt
    ⚠️ Optional: Basic template mode (without AI)
}
```

### Scenario 4: AI Provider Down

```swift
// Fallback to alternative providers
if anthropicDown {
    try await builder.generatePRD(
        from: request,
        fallbackToOpenAI: true  // Automatic failover
    )
}
```

---

## Comparison: Your Architecture vs My Original Suggestion

| Aspect                  | Your Architecture (Current) | My First Suggestion (Backend Intelligence) | This Suggestion (Encrypted Library) |
|-------------------------|-----------------------------|--------------------------------------------|-------------------------------------|
| **Offline Capability**  | ✅ Full                     | ❌ Limited (basic only)                    | ✅ Full                            |
| **Backend Dependency**  | ✅ Optional                 | ❌ Required for premium                    | ✅ Optional                        |
| **Graceful Degradation**| ✅ Works if backend down    | ❌ Fails if backend down                   | ✅ Works if backend down           |
| **IP Protection**       | ❌ Low (exposed in binary)  | ✅ High (backend only)                     | 🟡 Medium (encrypted)              |
| **User AI Keys**        | ✅ User-owned               | ❌ Backend manages                         | ✅ User-owned                      |
| **Performance**         | ✅ Fast (local)             | ⚠️ Network latency                         | ✅ Fast (local)                    |
| **Cost**                | ✅ Low (no backend compute) | ❌ High (backend AI calls)                 | ✅ Low (optional backend)          |

**Winner**: **Option 3 (Encrypted Library)** - Best of both worlds

---

## Implementation Timeline

### Phase 1: Encryption Infrastructure (Week 1-2)

- [ ] Implement LicenseManager
- [ ] Create encryption build script
- [ ] Test encrypted module loading
- [ ] Add license validation endpoints (minimal backend)

### Phase 2: Encrypted Library Build (Week 3-4)

- [ ] Identify proprietary modules to encrypt
- [ ] Create EncryptedCore wrapper
- [ ] Test decryption performance
- [ ] Ensure cross-platform compatibility (iOS/Android/Web)

### Phase 3: License Distribution (Week 5-6)

- [ ] Create license generation service
- [ ] Build purchase flow (Stripe/App Store)
- [ ] Implement device/user binding
- [ ] Add grace period handling

### Phase 4: Client Integration (Week 7-8)

- [ ] Update iOS app to use encrypted library
- [ ] Update Android app (via JNI bridge)
- [ ] Update Web app (via WASM)
- [ ] Test offline scenarios

### Phase 5: Security Hardening (Week 9-10)

- [ ] Add anti-debugging checks
- [ ] Obfuscate remaining code
- [ ] Legal protections (EULA, DMCA)
- [ ] Penetration testing

---

## Conclusion

### Your Original Architecture Was Right

Your instinct to keep ALL logic in the library was correct for:
- ✅ Resilience (works offline)
- ✅ Performance (no network latency)
- ✅ User control (own AI keys)
- ✅ Cost efficiency (no backend compute)

### The Missing Piece: Encryption

Add **runtime encryption** to protect IP:
- Proprietary code encrypted in binary
- License key decrypts at runtime
- Still works fully offline
- Backend optional (only for license validation)

### Best of Both Worlds

1. **Offline-first** - Full functionality without internet
2. **User-owned AI** - Users provide their own Anthropic/OpenAI keys
3. **IP Protected** - Core intelligence encrypted, license-gated
4. **Backend Optional** - Only for licensing, analytics, premium features
5. **Gracefully Degrades** - Backend down? Still works perfectly

### You Were Right

Your original architecture **is superior** to a backend-dependent approach. The fix is **encryption**, not **centralization**.

---

**Document Version**: 2.0
**Last Updated**: 2025-10-03
**Status**: Recommended Architecture
**Supersedes**: PROPRIETARY_ARCHITECTURE.md (v1.0)
