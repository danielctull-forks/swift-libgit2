// swift-tools-version: 6.2

import PackageDescription

// MARK: - Platform Configuration
//
// libgit2 requires different source files for different platforms. Since SPM's
// exclude/sources parameters cannot use .when(platforms:), we use #if os() for
// source file management and .when(platforms:) for all C settings.
//
// This means:
// - Same-platform builds work correctly (most common case)
// - Cross-compilation works when host and target have compatible sources
// - Cross-compilation from macOS to WASI requires source modifications
//
// Platform support:
// - Apple (macOS, iOS, tvOS, watchOS, visionOS): Full support
// - Linux: Full support with OpenSSL
// - Android: Full support with OpenSSL
// - Windows: Full support with WinHTTP and CNG
// - WASI: Limited support (requires building on Linux host)

let apple: [Platform] = [.iOS, .macOS, .tvOS, .visionOS, .watchOS]

var sourcePaths: [String] = []
var excludedPaths: [String] = []
var cSettings: [CSetting] = []
var linkerSettings: [LinkerSetting] = []

// MARK: - Core

sourcePaths += [
  "src/libgit2",
  "src/util",
]

excludedPaths += [
  // CMake build system files
  "src/libgit2/CMakeLists.txt",
  "src/libgit2/experimental.h.in",
  "src/libgit2/git2.rc",
  "src/libgit2/config.cmake.in",
  "src/util/CMakeLists.txt",
  "src/util/git2_features.h.in",
]

cSettings += [
  .headerSearchPath("src/libgit2"),
  .headerSearchPath("src/util"),
  .headerSearchPath("include"),
  .define("LIBGIT2_NO_FEATURES_H"),
  .define("GIT_ARCH_64", to: "1"),
]

// MARK: - Platform Utilities

#if os(Windows)
  excludedPaths += [
    "src/util/unix",
    "include/git2/stdint.h",
    "include/git2/sys/stream.h",
  ]
#else
  excludedPaths += ["src/util/win32"]
#endif

// MARK: - Threading

cSettings += [
  .define("GIT_THREADS", to: "1", .when(platforms: apple + [.android, .linux, .windows])),
  .define("GIT_THREADS_PTHREADS", to: "1", .when(platforms: apple + [.android, .linux])),
  .define("GIT_THREADS_NATIVE", to: "1", .when(platforms: [.windows])),
]

linkerSettings += [
  .linkedLibrary("pthread", .when(platforms: [.android, .linux])),
]

// MARK: - Zlib

sourcePaths += ["deps/zlib"]

excludedPaths += [
  "deps/zlib/CMakeLists.txt",
  "deps/zlib/LICENSE",
]

cSettings += [
  .headerSearchPath("deps/zlib"),
  .define("GIT_COMPRESSION_BUILTIN", to: "1"),
]

// Linux/Android link against system zlib for decompression
linkerSettings += [
  .linkedLibrary("z", .when(platforms: [.android, .linux])),
]

// MARK: - PCRE

sourcePaths += ["deps/pcre"]

excludedPaths += [
  "deps/pcre/CMakeLists.txt",
  "deps/pcre/COPYING",
  "deps/pcre/LICENCE",
  // Exclude cmake directory contents explicitly (directory exclusion with
  // trailing slash doesn't work reliably on Windows)
  "deps/pcre/cmake/COPYING-CMAKE-SCRIPTS",
  "deps/pcre/cmake/FindEditline.cmake",
  "deps/pcre/cmake/FindPackageHandleStandardArgs.cmake",
  "deps/pcre/cmake/FindReadline.cmake",
  "deps/pcre/config.h.in",
]

cSettings += [
  .headerSearchPath("deps/pcre"),
  .define("GIT_REGEX_BUILTIN", to: "1"),
  // PCRE configuration
  .define("SUPPORT_PCRE8", to: "1"),
  .define("HAVE_STDINT_H", to: "1"),
  .define("HAVE_INTTYPES_H", to: "1"),
  .define("HAVE_MEMMOVE", to: "1"),
  .define("HAVE_STRERROR", to: "1"),
  .define("LINK_SIZE", to: "2"),
  .define("PARENS_NEST_LIMIT", to: "250"),
  .define("MATCH_LIMIT", to: "10000000"),
  .define("MATCH_LIMIT_RECURSION", to: "10000000"),
  .define("NEWLINE", to: "10"),
  .define("NO_RECURSE", to: "1"),
  .define("POSIX_MALLOC_THRESHOLD", to: "10"),
  .define("BSR_ANYCRLF", to: "0"),
  .define("MAX_NAME_SIZE", to: "32"),
  .define("MAX_NAME_COUNT", to: "10000"),
]

// MARK: - xdiff

sourcePaths += ["deps/xdiff"]

excludedPaths += [
  "deps/xdiff/CMakeLists.txt",
]

cSettings += [
  .headerSearchPath("deps/xdiff"),
]

// MARK: - llhttp

sourcePaths += ["deps/llhttp"]

excludedPaths += [
  "deps/llhttp/CMakeLists.txt",
  "deps/llhttp/LICENSE-MIT",
]

cSettings += [
  .headerSearchPath("deps/llhttp"),
  .define("GIT_HTTPPARSER_BUILTIN", to: "1"),
]

// MARK: - Hash Implementations

cSettings += [
  .headerSearchPath("src/util/hash/sha1dc"),
  .headerSearchPath("src/util/hash/rfc6234"),
]

// Exclude mbedTLS hash backend (not used on any platform)
excludedPaths += [
  "src/util/hash/mbedtls.c",
  "src/util/hash/mbedtls.h",
]

// Exclude OpenSSL hash backend (we use CommonCrypto, CNG, or builtin)
excludedPaths += [
  "src/util/hash/openssl.c",
  "src/util/hash/openssl.h",
]

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  // Apple: Use CommonCrypto for hashing
  excludedPaths += [
    "src/util/hash/win32.c",
    "src/util/hash/win32.h",
    "src/util/hash/builtin.c",
    "src/util/hash/builtin.h",
    "src/util/hash/collisiondetect.c",
    "src/util/hash/collisiondetect.h",
    "src/util/hash/rfc6234",
    "src/util/hash/sha1dc",
  ]
#elseif os(Windows)
  // Windows: Use CNG for hashing
  excludedPaths += [
    "src/util/hash/common_crypto.c",
    "src/util/hash/common_crypto.h",
    "src/util/hash/builtin.c",
    "src/util/hash/builtin.h",
    "src/util/hash/collisiondetect.c",
    "src/util/hash/collisiondetect.h",
    "src/util/hash/rfc6234",
    "src/util/hash/sha1dc",
  ]
#else
  // Linux/Android/WASI: Use builtin SHA1DC + RFC6234
  excludedPaths += [
    "src/util/hash/common_crypto.c",
    "src/util/hash/common_crypto.h",
    "src/util/hash/win32.c",
    "src/util/hash/win32.h",
  ]
#endif

cSettings += [
  // Apple: CommonCrypto
  .define("GIT_SHA1_COMMON_CRYPTO", to: "1", .when(platforms: apple)),
  .define("GIT_SHA256_COMMON_CRYPTO", to: "1", .when(platforms: apple)),
  // Windows: CNG
  .define("GIT_SHA1_WIN32", to: "1", .when(platforms: [.windows])),
  .define("GIT_SHA256_WIN32", to: "1", .when(platforms: [.windows])),
  // Linux/Android/WASI: Builtin collision-detecting SHA1 + RFC6234 SHA256
  .define("GIT_SHA1_COLLISIONDETECT", to: "1", .when(platforms: [.android, .linux, .wasi])),
  .define("GIT_SHA256_BUILTIN", to: "1", .when(platforms: [.android, .linux, .wasi])),
  .define("SHA1DC_NO_STANDARD_INCLUDES", to: "1", .when(platforms: [.android, .linux, .wasi])),
  .define("SHA1DC_CUSTOM_INCLUDE_SHA1_C", to: "\"git2_util.h\"", .when(platforms: [.android, .linux, .wasi])),
  .define("SHA1DC_CUSTOM_INCLUDE_UBC_CHECK_C", to: "\"git2_util.h\"", .when(platforms: [.android, .linux, .wasi])),
]

// MARK: - TLS / HTTPS
//
// Note: openssl.c and mbedtls.c contain stub implementations that return 0 when
// their backends are disabled (no GIT_OPENSSL/GIT_MBEDTLS defined). These stubs
// are required because libgit2.c unconditionally calls git_openssl_stream_global_init
// and git_mbedtls_stream_global_init in its initialization. We include these files
// on all platforms to get the stubs.

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  // Apple: Use SecureTransport (but keep openssl.c/mbedtls.c for stubs)
  excludedPaths += [
    "src/libgit2/streams/openssl_dynamic.c",
    "src/libgit2/streams/openssl_dynamic.h",
    "src/libgit2/streams/openssl_legacy.c",
    "src/libgit2/streams/openssl_legacy.h",
    "src/libgit2/streams/schannel.c",
    "src/libgit2/streams/schannel.h",
  ]
#elseif os(Windows)
  // Windows: Use Schannel (via WinHTTP) (but keep openssl.c/mbedtls.c for stubs)
  excludedPaths += [
    "src/libgit2/streams/stransport.c",
    "src/libgit2/streams/stransport.h",
    "src/libgit2/streams/openssl_dynamic.c",
    "src/libgit2/streams/openssl_dynamic.h",
    "src/libgit2/streams/openssl_legacy.c",
    "src/libgit2/streams/openssl_legacy.h",
  ]
#else
  // Linux/Android: Use OpenSSL (dynamic linking) (but keep mbedtls.c for stub)
  excludedPaths += [
    "src/libgit2/streams/stransport.c",
    "src/libgit2/streams/stransport.h",
    "src/libgit2/streams/schannel.c",
    "src/libgit2/streams/schannel.h",
  ]
#endif

cSettings += [
  .define("GIT_HTTPS", to: "1", .when(platforms: apple + [.android, .linux, .windows])),
  // Apple: SecureTransport for TLS
  .define("GIT_SECURE_TRANSPORT", to: "1", .when(platforms: apple)),
  // Linux/Android: OpenSSL (dynamically loaded) for TLS
  .define("GIT_OPENSSL", to: "1", .when(platforms: [.android, .linux])),
  .define("GIT_OPENSSL_DYNAMIC", to: "1", .when(platforms: [.android, .linux])),
  // Windows: WinHTTP for HTTP transport, Schannel for TLS
  .define("GIT_WINHTTP", to: "1", .when(platforms: [.windows])),
  .define("GIT_SCHANNEL", to: "1", .when(platforms: [.windows])),
]

linkerSettings += [
  // Apple: Security and CoreFoundation frameworks for SecureTransport TLS
  .linkedFramework("Security", .when(platforms: apple)),
  .linkedFramework("CoreFoundation", .when(platforms: apple)),
  // Linux/Android: dlopen for OpenSSL
  .linkedLibrary("dl", .when(platforms: [.android, .linux])),
  // Windows: WinHTTP and crypto libraries
  .linkedLibrary("winhttp", .when(platforms: [.windows])),
  .linkedLibrary("crypt32", .when(platforms: [.windows])),
  .linkedLibrary("secur32", .when(platforms: [.windows])),
]

// MARK: - HTTP Transport

#if os(Windows)
  // Windows uses WinHTTP for HTTP transport
  excludedPaths += ["src/libgit2/transports/http.c"]
#else
  // All other platforms use standard HTTP transport
  excludedPaths += ["src/libgit2/transports/winhttp.c"]
#endif

// MARK: - NTLM Authentication

excludedPaths += [
  "deps/ntlmclient/CMakeLists.txt",
  // mbedTLS crypto backend (not used)
  "deps/ntlmclient/crypt_mbedtls.c",
  "deps/ntlmclient/crypt_mbedtls.h",
  "deps/ntlmclient/crypt_builtin_md4.c",
  // iconv unicode backend (we use builtin)
  "deps/ntlmclient/unicode_iconv.c",
  "deps/ntlmclient/unicode_iconv.h",
]

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  // Apple: Include ntlmclient with CommonCrypto
  sourcePaths += ["deps/ntlmclient"]
  excludedPaths += [
    "deps/ntlmclient/crypt_openssl.c",
    "deps/ntlmclient/crypt_openssl.h",
  ]
#elseif os(Windows)
  // Windows: WinHTTP handles NTLM natively, no ntlmclient needed
  excludedPaths += ["deps/ntlmclient"]
#else
  // Linux/Android: Include ntlmclient with OpenSSL
  sourcePaths += ["deps/ntlmclient"]
  excludedPaths += [
    "deps/ntlmclient/crypt_commoncrypto.c",
    "deps/ntlmclient/crypt_commoncrypto.h",
  ]
#endif

cSettings += [
  .headerSearchPath("deps/ntlmclient"),
  // Enable NTLM on platforms that use ntlmclient
  .define("GIT_AUTH_NTLM", to: "1", .when(platforms: apple + [.android, .linux])),
  .define("GIT_AUTH_NTLM_BUILTIN", to: "1", .when(platforms: apple + [.android, .linux])),
  .define("NTLM_STATIC", to: "1", .when(platforms: apple + [.android, .linux])),
  .define("UNICODE_BUILTIN", to: "1", .when(platforms: apple + [.android, .linux])),
  // Crypto backend selection
  .define("CRYPT_COMMONCRYPTO", .when(platforms: apple)),
  .define("CRYPT_OPENSSL", .when(platforms: [.android, .linux])),
  .define("CRYPT_OPENSSL_DYNAMIC", .when(platforms: [.android, .linux])),
  .define("OPENSSL_API_COMPAT", to: "0x10100000L", .when(platforms: [.android, .linux])),
]

// MARK: - SSH Transport

cSettings += [
  .define("GIT_SSH", to: "1", .when(platforms: [.android, .linux, .macOS])),
  .define("GIT_SSH_EXEC", to: "1", .when(platforms: [.android, .linux, .macOS])),
]

// MARK: - Process Spawning

cSettings += [
  .define("GIT_NO_PROCESS_SPAWN", .when(platforms: [.iOS, .tvOS, .visionOS, .wasi, .watchOS])),
]

// MARK: - Internationalization

cSettings += [
  .define("GIT_I18N", to: "1", .when(platforms: apple)),
  .define("GIT_I18N_ICONV", to: "1", .when(platforms: apple)),
]

linkerSettings += [
  .linkedLibrary("iconv", .when(platforms: apple)),
]

// MARK: - I/O and Polling

cSettings += [
  .define("GIT_IO_POLL", to: "1", .when(platforms: apple + [.android, .linux, .wasi])),
  .define("GIT_IO_WSAPOLL", to: "1", .when(platforms: [.windows])),
]

linkerSettings += [
  .linkedLibrary("ws2_32", .when(platforms: [.windows])),
]

// MARK: - qsort

cSettings += [
  .define("GIT_QSORT_BSD", .when(platforms: apple)),
  .define("GIT_QSORT_GNU", .when(platforms: [.android, .linux])),
  .define("GIT_QSORT_MSC", .when(platforms: [.windows])),
]

// MARK: - Nanosecond Timestamps

cSettings += [
  .define("GIT_NSEC", to: "1", .when(platforms: apple + [.android, .linux, .wasi])),
  .define("GIT_FUTIMENS", to: "1", .when(platforms: apple + [.android, .linux, .wasi])),
  .define("GIT_NSEC_MTIMESPEC", to: "1", .when(platforms: apple)),
  .define("GIT_NSEC_MTIM", to: "1", .when(platforms: [.android, .linux])),
]

// MARK: - Random Number Generation

cSettings += [
  .define("GIT_RAND_GETENTROPY", to: "1", .when(platforms: [.linux])),
  .define("GIT_RAND_GETLOADAVG", to: "1", .when(platforms: [.linux])),
]

// MARK: - Platform-Specific Compiler/Linker Flags

// GNU extensions for Linux/Android
cSettings += [
  .define("_GNU_SOURCE", .when(platforms: [.android, .linux])),
]

// Windows-specific defines
cSettings += [
  .define("WIN32", .when(platforms: [.windows])),
  .define("_WIN32_WINNT", to: "0x0600", .when(platforms: [.windows])),
  .define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows])),
  .define("_CRT_NONSTDC_NO_DEPRECATE", .when(platforms: [.windows])),
]

linkerSettings += [
  .linkedLibrary("rpcrt4", .when(platforms: [.windows])),
  .linkedLibrary("ole32", .when(platforms: [.windows])),
]

// MARK: - Package Definition

let package = Package(
  name: "swift-libgit2",
  products: [
    .library(name: "libgit2", targets: ["libgit2"])
  ],
  targets: [
    .target(
      name: "libgit2",
      path: ".",
      exclude: excludedPaths,
      sources: sourcePaths,
      publicHeadersPath: "include",
      cSettings: cSettings,
      linkerSettings: linkerSettings
    ),
  ]
)
