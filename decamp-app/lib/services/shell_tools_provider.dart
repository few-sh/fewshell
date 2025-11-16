import 'package:llm_dart/llm_dart.dart';

/// Shell execution tools for LLM
/// Direct Tool definitions - no translation layer needed
final shellTools = [
  Tool.function(
    name: 'execute_shell_command',
    description:
        'Execute a shell command on the server or infrastructure. '
        'Use this to run commands like checking logs, restarting services, '
        'checking disk space, process status, etc.',
    parameters: ParametersSchema(
      schemaType: 'object',
      properties: {
        'command': ParameterProperty(
          propertyType: 'string',
          description:
              'The shell command to execute. Do NOT include "sudo" prefix in the command string - use the sudo_required parameter instead. '
              'Examples: "systemctl restart nginx" (with sudo_required=true), "cat /var/log/syslog" (with sudo_required=true), '
              '"ps aux | grep nginx" (with sudo_required=false).',
        ),
        'sudo_required': ParameterProperty(
          propertyType: 'boolean',
          description:
              'Set to true if the command requires elevated privileges (sudo). '
              'IMPORTANT: Never include "sudo" in the command string itself - this parameter will handle privilege elevation securely. '
              'Use true for system operations like: service management, file operations in protected directories, package installation, system configuration. '
              'Use false for: reading logs accessible to the user, checking processes, network diagnostics available to all users.',
        ),
        'explanation': ParameterProperty(
          propertyType: 'string',
          description:
              'Brief explanation of what this command does and why it\'s needed',
        ),
      },
      required: ['command', 'sudo_required', 'explanation'],
    ),
  ),
];
