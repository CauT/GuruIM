// glog API compatibility shim
// Bridges old glog API (google::base::, plain int LogSeverity) to new glog API
// (google::logging::internal::, named LogSeverity type)
.text

// LogMessage(const char*, int, int) -> LogMessage(const char*, int, LogSeverity)
.globl __ZN6google10LogMessageC1EPKcii
.align 2
__ZN6google10LogMessageC1EPKcii:
    b __ZN6google10LogMessageC1EPKciNS_11LogSeverityE

.globl __ZN6google10LogMessageC2EPKcii
.align 2
__ZN6google10LogMessageC2EPKcii:
    b __ZN6google10LogMessageC2EPKciNS_11LogSeverityE

// LogMessageFatal(const char*, int, google::CheckOpString const&)
// -> LogMessageFatal(const char*, int, google::logging::internal::CheckOpString const&)
.globl __ZN6google15LogMessageFatalC1EPKciRKNS_13CheckOpStringE
.align 2
__ZN6google15LogMessageFatalC1EPKciRKNS_13CheckOpStringE:
    b __ZN6google15LogMessageFatalC1EPKciRKNS_7logging8internal13CheckOpStringE

.globl __ZN6google15LogMessageFatalC2EPKciRKNS_13CheckOpStringE
.align 2
__ZN6google15LogMessageFatalC2EPKciRKNS_13CheckOpStringE:
    b __ZN6google15LogMessageFatalC2EPKciRKNS_7logging8internal13CheckOpStringE

// GetExistingTempDirectories(vector*) -> GetExistingTempDirectories(vector&)
// Pointer and reference are ABI-identical on ARM64
.globl __ZN6google26GetExistingTempDirectoriesEPNSt3__16vectorINS0_12basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEENS5_IS7_EEEE
.align 2
__ZN6google26GetExistingTempDirectoriesEPNSt3__16vectorINS0_12basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEENS5_IS7_EEEE:
    b __ZN6google26GetExistingTempDirectoriesERNSt3__16vectorINS0_12basic_stringIcNS0_11char_traitsIcEENS0_9allocatorIcEEEENS5_IS7_EEEE

// google::base::CheckOpMessageBuilder -> google::logging::internal::CheckOpMessageBuilder
.globl __ZN6google4base21CheckOpMessageBuilderC1EPKc
.align 2
__ZN6google4base21CheckOpMessageBuilderC1EPKc:
    b __ZN6google7logging8internal21CheckOpMessageBuilderC1EPKc

.globl __ZN6google4base21CheckOpMessageBuilderC2EPKc
.align 2
__ZN6google4base21CheckOpMessageBuilderC2EPKc:
    b __ZN6google7logging8internal21CheckOpMessageBuilderC2EPKc

.globl __ZN6google4base21CheckOpMessageBuilderD1Ev
.align 2
__ZN6google4base21CheckOpMessageBuilderD1Ev:
    b __ZN6google7logging8internal21CheckOpMessageBuilderD1Ev

.globl __ZN6google4base21CheckOpMessageBuilderD2Ev
.align 2
__ZN6google4base21CheckOpMessageBuilderD2Ev:
    b __ZN6google7logging8internal21CheckOpMessageBuilderD2Ev

.globl __ZN6google4base21CheckOpMessageBuilder7ForVar2Ev
.align 2
__ZN6google4base21CheckOpMessageBuilder7ForVar2Ev:
    b __ZN6google7logging8internal21CheckOpMessageBuilder7ForVar2Ev

.globl __ZN6google4base21CheckOpMessageBuilder9NewStringEv
.align 2
__ZN6google4base21CheckOpMessageBuilder9NewStringEv:
    b __ZN6google7logging8internal21CheckOpMessageBuilder9NewStringEv
