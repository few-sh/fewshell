import 'package:llm_dart/llm_dart.dart';

/// Tool name constants
const String kExecuteShellCommand = 'execute_shell_command';
const String kFetch = 'fetch';

/// Shell execution tools for LLM
/// Direct Tool definitions - no translation layer needed
final shellTools = [
  Tool.function(
    name: kExecuteShellCommand,
    description:
        'Executes a shell command on the server or infrastructure returns its resulting output of stdout, stderr and exitCode'
        'Use this to run commands like checking logs, restarting services, '
        'checking disk space, process status, etc. '
        'Returns JSON with the fields: stdout, stderr and exitCode that contain the standard output, error message and exit code respectively and '
        'an additional executed field. The executed field simply indicates that the command executed regardless of whether the command itself has an error.',
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
  Tool.function(
    name: kFetch,
    description:
        'Performs an HTTP request to a specified URL, similar to the curl command-line tool. '
        'Returns the response status code, headers, and body. '
        'Use this for API interactions, downloading files, or checking web endpoints.',
    parameters: ParametersSchema(
      schemaType: 'object',
      properties: {
        'url': ParameterProperty(
          propertyType: 'string',
          description: 'The target URL for the request.',
        ),
        'method': ParameterProperty(
          propertyType: 'string',
          description:
              'The HTTP method to use. Defaults to "GET" if not specified.',
          enumList: [
            'GET',
            'POST',
            'PUT',
            'DELETE',
            'PATCH',
            'HEAD',
            'OPTIONS',
          ],
        ),
        'headers': ParameterProperty(
          propertyType: 'object',
          description:
              'A JSON object representing the HTTP headers (key-value pairs).',
        ),
        'body': ParameterProperty(
          propertyType: 'string',
          description:
              'The request body data. Useful for POST, PUT, and PATCH requests.',
        ),
        'timeout': ParameterProperty(
          propertyType: 'number',
          description:
              'Request timeout in seconds. Defaults to 30 seconds if not specified.',
        ),
        'explanation': ParameterProperty(
          propertyType: 'string',
          description: 'Brief explanation of the purpose of this HTTP request.',
        ),
      },
      required: ['url', 'method', 'explanation'],
    ),
  ),
];
