class AuditResult {
  const AuditResult({required this.isValid, this.errorMessage});
  
  final bool isValid;
  final String? errorMessage;
  
  factory AuditResult.pass() => const AuditResult(isValid: true);
  factory AuditResult.fail(String msg) => AuditResult(isValid: false, errorMessage: msg);
}
