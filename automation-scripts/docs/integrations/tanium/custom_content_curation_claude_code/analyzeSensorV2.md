# analyzeSensorV2

Analyze a Tanium sensor JSON file and generate a comprehensive analysis report with enhanced context tracking, producing both JSON and human-readable text outputs.

## Usage

```
/analyzeSensorV2 <sensor-file.json>
```

## Arguments

- `sensor-file.json`: Path to the Tanium sensor JSON file to analyze (relative to project root)

## Description

This command performs a comprehensive analysis of a Tanium sensor JSON file, providing:

- **Generated Description**: Code-analyzed description of what the sensor does
- **Supported Operating Systems**: List of platforms with actual implementations
- **Detailed Execution Flow**: Step-by-step breakdown of sensor operations with integrated script analysis and context requirements highlighted
- **Context Requirements**: Items flagged as needing additional information for complete analysis, including relevant code snippets
- **Best Practices Recommendations**: Suggestions for improving sensor implementation, security, performance, and maintainability

## Examples

```
/analyzeSensorV2 "Tanium Sensors/AD Site Name OU Match.json"
/analyzeSensorV2 sensors/registry-query.json
```

## Output

The command will:
1. Display the full analysis in the conversation
2. Save the structured analysis to `Tanium Sensor Analysis/[filename]_analysis.json` for tool integration
3. Save the human-readable analysis to `Tanium Sensor Analysis/[filename]_analysis.txt` for easy review
4. Update `additional_context_needed.json` with flagged items requiring more context, including relevant code snippets

## Implementation

I'll analyze the Tanium sensor JSON file by:
1. Loading and parsing the JSON structure
2. Identifying supported operating systems (excluding "not supported" implementations)
3. Generating a code-based description of sensor functionality
4. Creating detailed execution flow with integrated script content analysis including data sources, collection methods, and operations
5. Flagging areas requiring additional context for complete analysis with relevant code snippets
6. Evaluating sensor implementation against best practices and providing actionable recommendations for improvement
8. Saving results to console output, structured JSON analysis file, and human-readable text file

The analysis identifies data sources (Registry, WMI, XML, File System), collection methods, data manipulations, dependencies, and context requirements, formatted as a structured JSON report with execution flow details. Best practices recommendations cover areas such as error handling, security considerations, performance optimization, cross-platform compatibility, and maintainability improvements. Context requirements include specific code snippets that triggered the flagging for enhanced troubleshooting and analysis.