// Source: @anthropic-ai/claude-agent-sdk@0.3.287 sdk-tools.d.ts (JSDoc comments stripped). Tool input/output schemas.
/* eslint-disable */
export type ToolInputSchemas =
  | AgentInput
  | BashInput
  | ExitPlanModeInput
  | FileEditInput
  | FileReadInput
  | FileWriteInput
  | GlobInput
  | GrepInput
  | TaskStopInput
  | ListMcpResourcesInput
  | RefreshMcpToolsInput
  | McpInput
  | NotebookEditInput
  | ReadMcpResourceDirInput
  | ReadMcpResourceInput
  | ReportFindingsInput
  | TodoWriteInput
  | WebFetchInput
  | WebSearchInput
  | AskUserQuestionInput
  | SendFeedbackInput
  | ClaudeDesignInput
  | ProjectsInput
  | EnterPlanModeInput
  | TaskCreateInput
  | TaskGetInput
  | TaskUpdateInput
  | TaskListInput
  | WorkflowInput
  | CronCreateInput
  | CronDeleteInput
  | CronListInput
  | ScheduleWakeupInput
  | RemoteTriggerInput
  | ShowOnboardingRolePickerInput
  | ReadNotificationsInput
  | MonitorInput
  | ProposeSkillsInput
  | ProposeGoalInput
  | ArtifactInput
  | PushNotificationInput
  | EnterWorktreeInput
  | ExitWorktreeInput
  | ToolOutputSchemas;
export type ToolOutputSchemas =
  | AgentOutput
  | BashOutput
  | ExitPlanModeOutput
  | FileEditOutput
  | FileReadOutput
  | FileWriteOutput
  | GlobOutput
  | GrepOutput
  | TaskStopOutput
  | ListMcpResourcesOutput
  | RefreshMcpToolsOutput
  | McpOutput
  | NotebookEditOutput
  | ReadMcpResourceDirOutput
  | ReadMcpResourceOutput
  | ReportFindingsOutput
  | TodoWriteOutput
  | WebFetchOutput
  | WebSearchOutput
  | AskUserQuestionOutput
  | SendFeedbackOutput
  | EnterWorktreeOutput
  | ExitWorktreeOutput
  | TaskCreateOutput
  | TaskGetOutput
  | TaskUpdateOutput
  | TaskListOutput
  | ArtifactOutput
  | RemoteTriggerOutput
  | ShowOnboardingRolePickerOutput
  | ReadNotificationsOutput
  | ScheduleWakeupOutput
  | MonitorOutput
  | ProposeSkillsOutput
  | ProposeGoalOutput
  | EnterPlanModeOutput
  | WorkflowOutput
  | CronCreateOutput
  | CronDeleteOutput
  | CronListOutput
  | PushNotificationOutput
  | ClaudeDesignOutput
  | ProjectsOutput;
export type AgentOutput =
  | {
      agentId: string;
      agentType?: string;
      content: {
        type: "text";
        text: string;
        citations?: unknown[] | null;
      }[];
      resolvedModel?: string;
      modelsUsed?: string[];
      totalToolUseCount: number;
      totalDurationMs: number;
      totalTokens: number;
      usage: {
        input_tokens: number;
        output_tokens: number;
        cache_creation_input_tokens: number | null;
        cache_read_input_tokens: number | null;
        server_tool_use: {
          web_search_requests: number;
          web_fetch_requests: number;
        } | null;
        service_tier: string | null;
        cache_creation: {
          ephemeral_1h_input_tokens: number;
          ephemeral_5m_input_tokens: number;
        } | null;
        inference_geo?: string | null;
        speed?: string | null;
        iterations?: unknown;
        output_tokens_details?: {
          thinking_tokens?: number | null;
        } | null;
        fallback_credit?: unknown;
      };
      toolStats?: {
        readCount: number;
        searchCount: number;
        bashCount: number;
        editFileCount: number;
        linesAdded: number;
        linesRemoved: number;
        otherToolCount: number;
        frameCount?: number;
      };
      status: "completed";
      prompt: string;
      worktreePath?: string;
      worktreeBranch?: string;
    }
  | {
      status: "async_launched";
      isAsync?: true;
      agentId: string;
      description: string;
      resolvedModel?: string;
      modelsUsed?: string[];
      prompt: string;
      outputFile: string;
      canReadOutputFile?: boolean;
    }
  | {
      status: "remote_launched";
      taskId: string;
      sessionUrl: string;
      description: string;
      prompt: string;
      outputFile: string;
    };
export type FileReadOutput =
  | {
      type: "text";
      file: {
        filePath: string;
        content: string;
        numLines: number;
        startLine: number;
        totalLines: number;
        truncatedByTokenCap?: boolean;
      };
      artifactRead?: {
        slug: string;
        ver: string;
      };
    }
  | {
      type: "image";
      file: {
        base64: string;
        type: "image/jpeg" | "image/png" | "image/gif" | "image/webp";
        originalSize: number;
        dimensions?: {
          originalWidth?: number;
          originalHeight?: number;
          displayWidth?: number;
          displayHeight?: number;
        };
      };
    }
  | {
      type: "notebook";
      file: {
        filePath: string;
        cells: unknown[];
      };
    }
  | {
      type: "pdf";
      file: {
        filePath: string;
        base64: string;
        originalSize: number;
      };
    }
  | {
      type: "parts";
      file: {
        filePath: string;
        originalSize: number;
        count: number;
        outputDir: string;
      };
      firstPage?: number;
      pages?: {
        base64: string;
        mediaType: "image/jpeg" | "image/png" | "image/gif" | "image/webp";
        error?: string;
      }[];
    }
  | {
      type: "file_unchanged";
      file: {
        filePath: string;
      };
      source?: "seeded";
    };
export type ListMcpResourcesOutput = {
  uri: string;
  name: string;
  mimeType?: string;
  description?: string;
  server: string;
}[];
export type RefreshMcpToolsOutput = {
  server: string;
  status: "refreshed" | "error" | "not_connected";
  toolCount?: number;
  added?: string[];
  removed?: string[];
  error?: string;
}[];
export type McpOutput =
  | string
  | {
      type: string;
      [k: string]: unknown;
    }[]
  | {
      [k: string]: unknown;
    };
export type ArtifactOutput =
  | {
      url: string;
      path: string;
      artifact_id?: string;
      title?: string;
      version?: string;
      capabilities?: unknown;
      stored?: {
        contract: string;
        preferredContract?: string;
        capabilities?: {
          [k: string]: unknown;
        };
        carried?: boolean;
        read?: string;
      };
      warnings?: string[];
      publishesRemaining?: number;
      publishesResetAt?: number;
      contract?: string;
      updated?: boolean;
      icon?: string;
      faviconSent?: true;
      iconDropped?: true;
      audience?: string;
      seq?: number;
      unchanged?: true;
      liveSubscription?: string;
      pinned?: boolean;
    }
  | {
      artifacts: {
        title: string;
        url: string;
        favicon?: string;
        updatedAt?: string;
        rel?: "mine" | "shared";
        external?: true;
        role?: "editor" | "commenter" | "reader" | "viewer";
        pinned?: boolean;
      }[];
      truncated?: boolean;
      pins_enabled?: boolean;
      scope?: "shared" | "all";
      external_listed?: true;
    }
  | {
      read: {
        url: string;
        bytes: number;
        code: number;
        codeText: string;
        result: string;
        durationMs: number;
        title?: string;
      };
      artifactRead?: {
        slug: string;
        ver?: string;
        seeded?: false;
      };
    }
  | {
      watch: {
        url: string;
        watching: boolean;
        outcome: string;
        reason?: string;
        durable_skip_reason?: string;
        task_id?: string;
        since?: number;
        token_expires_at?: number;
        rail?: string;
        trigger_id?: string;
        durable_since?: string;
        status?: number;
        detail?: string;
        note?: string;
        events?: string[];
      };
    }
  | {
      unwatch: {
        url: string;
        was_watching: boolean;
      };
    }
  | {
      watches: (
        | {
            url: string;
            task_id: string;
            since: number;
            explicit: boolean;
            connected: boolean;
            connecting?: boolean;
            token_expires_at: number;
            armed_via?: string;
          }
        | {
            url: string;
            rail: "durable_wake";
            trigger_id: string;
            since: string;
            events?: string[];
            restored?: boolean;
          }
        | {
            url: string;
            rail: "live_stopped";
            since?: number;
            explicit?: boolean;
            armed_via?: string;
            stop_kind: string;
          }
      )[];
      filter_url?: string;
      arms?: {
        url: string;
        rail?: string;
        state: string;
        reconnect?: boolean;
        failures?: number;
        max_failures?: number;
        next_in_s?: number;
        last_failure?: string;
        reason?: string;
        detail?: string;
        server_message?: string;
        at?: number;
      }[];
    }
  | {
      written?: {
        url: string;
      };
      asset_upload: {
        id: string;
        url: string;
        size_bytes: number;
        content_type: string;
        sha256?: string;
        file_name: string;
      };
    }
  | {
      written?: {
        url: string;
      };
      asset_uploads: {
        url: string;
        results: [
          (
            | {
                file_path: string;
                status: "uploaded";
                id: string;
                url: string;
                size_bytes: number;
                content_type: string;
                sha256?: string;
                file_name: string;
              }
            | {
                file_path: string;
                status: "failed" | "not_attempted";
                reason: string;
                message: string;
                may_be_stored?: true;
              }
          ),
          ...(
            | {
                file_path: string;
                status: "uploaded";
                id: string;
                url: string;
                size_bytes: number;
                content_type: string;
                sha256?: string;
                file_name: string;
              }
            | {
                file_path: string;
                status: "failed" | "not_attempted";
                reason: string;
                message: string;
                may_be_stored?: true;
              }
          )[]
        ];
      };
    }
  | {
      asset_list: {
        url: string;
        assets: {
          id: string;
          url: string;
          content_type: string;
          size_bytes: number;
          sha256?: string;
          created_at: string;
        }[];
        usage: {
          files: number;
          bytes: number;
          max_files: number;
          max_bytes: number;
        };
        next?: string;
        cowritten?: true;
        outside_writer?: true;
      };
    }
  | {
      asset_read: {
        id: string;
        path: string;
        size_bytes: number;
        content_type: string;
        sha256: string;
        cowritten?: true;
        outside_writer?: true;
        public_read?: true;
        foreign?: true;
      };
    }
  | {
      written?: {
        url: string;
      };
      asset_delete: {
        id: string;
        deleted: boolean;
      };
    }
  | {
      pin: {
        action: "pin" | "unpin";
        url: string;
        pinned: boolean;
        title?: string;
      };
    };
export type ProjectsOutput =
  | {
      method: "project_info";
      notice?: string;
      name: string;
      description: string;
      instructions: string;
      docs: {
        path: string;
        created_at: string | null;
      }[];
      files?: {
        path: string;
        file_kind: string;
        created_at: string | null;
      }[];
      sync_sources?: {
        type: string | null;
        config: {
          [k: string]: unknown;
        };
      }[];
      knowledge: {
        knowledge_size: number;
        max_knowledge_size: number;
      };
    }
  | {
      method: "project_read";
      notice?: string;
      path: string;
      file_kind?: string;
      content?: string;
      local_file?: string;
      created_at: string | null;
    }
  | {
      method: "project_search";
      notice?: string;
      rag: boolean;
      hits?: {
        name?: string;
        doc_uuid?: string;
        text?: string;
      }[];
      docs?: string[];
    }
  | {
      method: "project_write";
      notice?: string;
      path: string;
      doc_uuid: string;
      replaced: boolean;
      present_to_user?: boolean;
      local_path?: string;
    }
  | {
      method: "project_delete";
      notice?: string;
      path: string;
      deleted: boolean;
    }
  | {
      method: "project_memory_list";
      notice?: string;
      files: {
        path: string;
        size_bytes: number;
        updated_at: string | null;
        truncated: boolean;
      }[];
      truncated: boolean;
    }
  | {
      method: "project_memory_read";
      notice?: string;
      path: string;
      content?: string;
      local_file?: string;
      size_bytes: number;
      updated_at: string | null;
      truncated: boolean;
    };
export interface AgentInput {
  description: string;
  prompt: string;
  subagent_type?: string;
  model?: "sonnet" | "opus" | "haiku" | "fable";
  run_in_background?: boolean;
  name?: string;
  team_name?: string;
  mode?: "acceptEdits" | "auto" | "bypassPermissions" | "default" | "dontAsk" | "plan";
  isolation?: "worktree" | "remote";
}
export interface BashInput {
  command: string;
  timeout?: number;
  description?: string;
  run_in_background?: boolean;
  dangerouslyDisableSandbox?: boolean;
}
export interface ExitPlanModeInput {
  allowedPrompts?: {
    tool: "Bash";
    prompt: string;
  }[];
  [k: string]: unknown;
}
export interface FileEditInput {
  file_path: string;
  old_string: string;
  new_string: string;
  replace_all?: boolean;
}
export interface FileReadInput {
  file_path: string;
  offset?: number;
  limit?: number;
  pages?: string;
}
export interface FileWriteInput {
  file_path: string;
  content: string;
}
export interface GlobInput {
  pattern: string;
  path?: string;
}
export interface GrepInput {
  pattern: string;
  path?: string;
  glob?: string;
  output_mode?: "content" | "files_with_matches" | "count";
  "-B"?: number;
  "-A"?: number;
  "-C"?: number;
  context?: number;
  "-n"?: boolean;
  "-i"?: boolean;
  "-o"?: boolean;
  type?: string;
  head_limit?: number;
  offset?: number;
  multiline?: boolean;
}
export interface TaskStopInput {
  task_id?: string;
  shell_id?: string;
}
export interface ListMcpResourcesInput {
  server?: string;
}
export interface RefreshMcpToolsInput {
  server?: string;
}
export interface McpInput {
  [k: string]: unknown;
}
export interface NotebookEditInput {
  notebook_path: string;
  cell_id?: string;
  new_source: string;
  cell_type?: "code" | "markdown";
  edit_mode?: "replace" | "insert" | "delete";
}
export interface ReadMcpResourceDirInput {
  server: string;
  uri: string;
}
export interface ReadMcpResourceInput {
  server: string;
  uri: string;
}
export interface ReportFindingsInput {
  level?: "low" | "medium" | "high" | "xhigh" | "max";
  findings: {
    file: string;
    line?: number;
    summary: string;
    short_summary?: string;
    failure_scenario: string;
    category?: string;
    verdict?: "CONFIRMED" | "PLAUSIBLE";
    outcome?: "fixed" | "skipped" | "no_change_needed";
  }[];
}
export interface TodoWriteInput {
  todos: {
    content: string;
    status: "pending" | "in_progress" | "completed";
    activeForm: string;
  }[];
}
export interface WebFetchInput {
  url: string;
  prompt: string;
}
export interface WebSearchInput {
  query: string;
  allowed_domains?: string[];
  blocked_domains?: string[];
}
export interface AskUserQuestionInput {
  questions:
    | [
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        }
      ]
    | [
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        }
      ]
    | [
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        }
      ]
    | [
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        },
        {
          question: string;
          header: string;
          options:
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ]
            | [
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                },
                {
                  label: string;
                  description: string;
                  preview?: string;
                }
              ];
          multiSelect: boolean;
        }
      ];
  answers?: {
    [k: string]: string;
  };
  annotations?: {
    [k: string]: {
      preview?: string;
      notes?: string;
    };
  };
  metadata?: {
    source?: string;
  };
}
export interface SendFeedbackInput {
  type: "bug" | "idea" | "missing_capability";
  title: string;
  details: string;
  area?: string;
  failure_mode?:
    | "instruction_following"
    | "destructive_actions"
    | "code_quality"
    | "repetition_and_looping"
    | "model_regression"
    | "overconfidence_and_hallucination"
    | "context_and_memory"
    | "overeager"
    | "over_correction"
    | "stopping_short"
    | "dispute_or_decline"
    | "subagent_overspawn"
    | "tone_or_preachiness"
    | "excessive_questions"
    | "unwanted_scope"
    | "other";
  task_category?: "code_edit" | "debug" | "explain" | "plan" | "shell" | "search" | "review" | "other";
}
export interface ClaudeDesignInput {
  operation: string;
  arguments: {
    [k: string]: unknown;
  };
}
export interface ProjectsInput {
  method:
    | "project_info"
    | "project_read"
    | "project_search"
    | "project_write"
    | "project_delete"
    | "project_memory_list"
    | "project_memory_read";
  path?: string;
  content?: string;
  local_path?: string;
  present_to_user?: boolean;
  query?: string;
  n?: number;
}
export interface EnterPlanModeInput {}
export interface TaskCreateInput {
  subject: string;
  description: string;
  activeForm?: string;
  metadata?: {
    [k: string]: unknown;
  };
}
export interface TaskGetInput {
  taskId: string;
}
export interface TaskUpdateInput {
  taskId: string;
  subject?: string;
  description?: string;
  activeForm?: string;
  status?: ("pending" | "in_progress" | "completed") | "deleted";
  addBlocks?: string[];
  addBlockedBy?: string[];
  owner?: string;
  metadata?: {
    [k: string]: unknown;
  };
}
export interface TaskListInput {}
export interface WorkflowInput {
  script?: string;
  name?: string;
  description?: string;
  title?: string;
  args?: {
    [k: string]: unknown;
  };
  scriptPath?: string;
  resumeFromRunId?: string;
}
export interface CronCreateInput {
  cron: string;
  prompt: string;
  recurring?: boolean;
  durable?: boolean;
}
export interface CronDeleteInput {
  id: string;
}
export interface CronListInput {}
export interface ScheduleWakeupInput {
  delaySeconds?: number;
  reason?: string;
  prompt?: string;
  stop?: boolean;
  noop?: boolean;
}
export interface RemoteTriggerInput {
  action: "list" | "get" | "create" | "update" | "run" | "create_webhook_trigger" | "list_runs" | "get_run_log";
  trigger_id?: string;
  session_id?: string;
  cursor?: string;
  body?: {
    [k: string]: unknown;
  };
}
export interface ShowOnboardingRolePickerInput {}
export interface ReadNotificationsInput {}
export interface MonitorInput {
  description: string;
  timeout_ms: number;
  command?: string;
  ws?: {
    url: string;
    protocols?: string[];
  };
}
export interface ProposeSkillsInput {
  proposals:
    | [
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        }
      ]
    | [
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        },
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        }
      ]
    | [
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        },
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        },
        {
          name: string;
          kind: "new" | "improvement";
          target?: string;
          description: string;
          evidence?: string[];
          skillMd: string;
        }
      ];
}
export interface ProposeGoalInput {
  condition: string;
  ask_user?: boolean;
}
export interface ArtifactInput {
  action?:
    | "publish"
    | "list"
    | "read"
    | "list_types"
    | "watch"
    | "unwatch"
    | "status"
    | "upload_asset"
    | "list_assets"
    | "read_asset"
    | "delete_asset"
    | "pin"
    | "unpin";
  file_path?: string;
  favicon?: string;
  icon?: string;
  limit?: number;
  scope?: "mine" | "shared" | "all";
  title?: string;
  description?: string;
  label?: string;
  url?: string;
  prompt?: string;
  force?: boolean;
  pin?: boolean;
  out_dir?: string;
  file_paths?: [string, ...string[]];
  asset_id?: string;
  after?: string;
  capabilities?: {
    [k: string]: unknown;
  };
  contract?: "latest" | string;
}
export interface PushNotificationInput {
  message: string;
  status: "proactive";
}
export interface EnterWorktreeInput {
  name?: string;
  path?: string;
}
export interface ExitWorktreeInput {
  action: "keep" | "remove";
  discard_changes?: boolean;
}
export interface BashOutput {
  stdout: string;
  stderr: string;
  rawOutputPath?: string;
  interrupted: boolean;
  isImage?: boolean;
  backgroundTaskId?: string;
  backgroundedByUser?: boolean;
  timedOutAfterMs?: number;
  backgroundCwdHint?: string;
  backgroundEndsWithFinalResponse?: true;
  dangerouslyDisableSandbox?: boolean;
  returnCodeInterpretation?: string;
  noOutputExpected?: boolean;
  structuredContent?: unknown[];
  persistedOutputPath?: string;
  persistedOutputSize?: number;
  staleReadFileStateHint?: string;
  ghRateLimitHint?: string;
  gitOperation?: {
    commit?: {
      sha: string;
      kind: "committed" | "amended" | "cherry-picked";
      branch?: string;
    };
    push?: {
      branch: string;
    };
    branch?: {
      ref: string;
      action: "merged" | "rebased";
    };
    pr?: {
      number: number;
      url?: string;
      action:
        | "created"
        | "edited"
        | "merged"
        | "commented"
        | "closed"
        | "reopened"
        | "ready"
        | "draft"
        | "auto-merge-enabled"
        | "auto-merge-disabled";
    };
  };
}
export interface ExitPlanModeOutput {
  plan: string | null;
  isAgent: boolean;
  filePath?: string;
  hasTaskTool?: boolean;
  planWasEdited?: boolean;
  awaitingLeaderApproval?: boolean;
  requestId?: string;
}
export interface FileEditOutput {
  filePath: string;
  oldString: string;
  newString: string;
  originalFile: string | null;
  structuredPatch: {
    oldStart: number;
    oldLines: number;
    newStart: number;
    newLines: number;
    lines: string[];
  }[];
  userModified: boolean;
  replaceAll: boolean;
  gitDiff?: {
    filename: string;
    status: "modified" | "added";
    additions: number;
    deletions: number;
    changes: number;
    patch: string;
    repository?: string | null;
  };
  staged?: boolean;
}
export interface FileWriteOutput {
  type: "create" | "update";
  filePath: string;
  content: string;
  structuredPatch: {
    oldStart: number;
    oldLines: number;
    newStart: number;
    newLines: number;
    lines: string[];
  }[];
  originalFile: string | null;
  gitDiff?: {
    filename: string;
    status: "modified" | "added";
    additions: number;
    deletions: number;
    changes: number;
    patch: string;
    repository?: string | null;
  };
  userModified?: boolean;
  staged?: boolean;
}
export interface GlobOutput {
  durationMs: number;
  numFiles: number;
  filenames: string[];
  truncated: boolean;
  totalMatches?: number;
  countIsComplete?: boolean;
}
export interface GrepOutput {
  mode?: "content" | "files_with_matches" | "count";
  numFiles: number;
  filenames: string[];
  content?: string;
  numLines?: number;
  numMatches?: number;
  totalFiles?: number;
  totalLines?: number;
  appliedLimit?: number;
  appliedOffset?: number;
}
export interface TaskStopOutput {
  message: string;
  task_id: string;
  task_type: string;
  command?: string;
}
export interface NotebookEditOutput {
  new_source: string;
  old_source?: string;
  cell_id?: string;
  cell_type: "code" | "markdown";
  language: string;
  edit_mode: string;
  error?: string;
  notebook_path: string;
  original_file: string;
  updated_file: string;
}
export interface ReadMcpResourceDirOutput {
  resources: {
    uri: string;
    name: string;
    mimeType?: string;
  }[];
  error?: string;
}
export interface ReadMcpResourceOutput {
  contents: {
    uri: string;
    mimeType?: string;
    text?: string;
    blobSavedTo?: string;
  }[];
  error?: string;
}
export interface ReportFindingsOutput {
  count: number;
  level?: "low" | "medium" | "high" | "xhigh" | "max";
  findings: {
    file: string;
    line?: number;
    summary: string;
    short_summary?: string;
    failure_scenario: string;
    category?: string;
    verdict?: "CONFIRMED" | "PLAUSIBLE";
    outcome?: "fixed" | "skipped" | "no_change_needed";
  }[];
}
export interface TodoWriteOutput {
  oldTodos: {
    content: string;
    status: "pending" | "in_progress" | "completed";
    activeForm: string;
  }[];
  newTodos: {
    content: string;
    status: "pending" | "in_progress" | "completed";
    activeForm: string;
  }[];
}
export interface WebFetchOutput {
  bytes: number;
  code: number;
  codeText: string;
  result: string;
  durationMs: number;
  url: string;
  artifactRead?: {
    slug: string;
    ver?: string;
    seeded?: false;
  };
}
export interface WebSearchOutput {
  query: string;
  results: (
    | {
        tool_use_id: string;
        content: {
          title: string;
          url: string;
        }[];
      }
    | string
  )[];
  durationSeconds: number;
  searchCount?: number;
}
export interface AskUserQuestionOutput {
  questions: {
    question: string;
    header: string;
    options:
      | [
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          }
        ]
      | [
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          }
        ]
      | [
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          },
          {
            label: string;
            description: string;
            preview?: string;
          }
        ];
    multiSelect: boolean;
  }[];
  answers: {
    [k: string]: string;
  };
  response?: string;
  annotations?: {
    [k: string]: {
      preview?: string;
      notes?: string;
    };
  };
  afkTimeoutMs?: number;
}
export interface SendFeedbackOutput {
  success: boolean;
  message: string;
}
export interface EnterWorktreeOutput {
  worktreePath: string;
  worktreeBranch?: string;
  message: string;
}
export interface ExitWorktreeOutput {
  action: "keep" | "remove";
  originalCwd: string;
  worktreePath: string;
  worktreeBranch?: string;
  tmuxSessionName?: string;
  discardedFiles?: number;
  discardedCommits?: number;
  message: string;
}
export interface TaskCreateOutput {
  task: {
    id: string;
    subject: string;
  };
}
export interface TaskGetOutput {
  task: {
    id: string;
    subject: string;
    description: string;
    status: "pending" | "in_progress" | "completed";
    blocks: string[];
    blockedBy: string[];
  } | null;
}
export interface TaskUpdateOutput {
  success: boolean;
  taskId: string;
  updatedFields: string[];
  error?: string;
  statusChange?: {
    from: string;
    to: string;
  };
}
export interface TaskListOutput {
  tasks: {
    id: string;
    subject: string;
    status: "pending" | "in_progress" | "completed";
    owner?: string;
    blockedBy: string[];
  }[];
}
export interface RemoteTriggerOutput {
  status: number;
  json: string;
  summary?: string;
}
export interface ShowOnboardingRolePickerOutput {
  role?: string;
  dismissed?: boolean;
}
export interface ReadNotificationsOutput {
  notifications: {
    notification_id: string;
    origin: string;
    queued_at: string;
    content: string;
  }[];
  remaining: number;
}
export interface ScheduleWakeupOutput {
  scheduledFor: number;
  clampedDelaySeconds: number;
  wasClamped: boolean;
  stopped?: boolean;
  cancelledWakeups?: number;
}
export interface MonitorOutput {
  taskId: string;
  timeoutMs: number;
  persistent?: boolean;
}
export interface ProposeSkillsOutput {
  proposalCount: number;
}
export interface ProposeGoalOutput {
  condition: string;
  askUser: boolean;
}
export interface EnterPlanModeOutput {
  message: string;
}
export interface WorkflowOutput {
  status: "async_launched" | "remote_launched";
  taskId: string;
  taskType?: "local_workflow" | "remote_agent";
  workflowName?: string;
  runId?: string;
  summary?: string;
  transcriptDir?: string;
  scriptPath?: string;
  sessionUrl?: string;
  warning?: string;
  error?: string;
}
export interface CronCreateOutput {
  id: string;
  humanSchedule: string;
  recurring: boolean;
  durable?: boolean;
}
export interface CronDeleteOutput {
  id: string;
}
export interface CronListOutput {
  jobs: {
    id: string;
    cron: string;
    humanSchedule: string;
    prompt: string;
    recurring?: boolean;
    durable?: boolean;
  }[];
}
export interface PushNotificationOutput {
  message: string;
  pushSent?: boolean;
  localSent?: boolean;
  disabledReason?: "config_off" | "user_present" | "no_transport";
  sentAt?: string;
}
export interface ClaudeDesignOutput {
  operation: string;
  content: {
    [k: string]: unknown;
  }[];
  isError?: boolean;
}
