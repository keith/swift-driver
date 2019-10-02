/// Planning for builds
extension Driver {
  /// Plan a standard compilation, which produces jobs for compiling separate
  /// primary files.
  private mutating func planStandardCompile() -> [Job] {
    var jobs = [Job]()

    // Keep track of the various outputs we care about from the jobs we build.
    var linkerInputs: [InputFile] = []
    var moduleInputs: [InputFile] = []
    func addJobOutputs(_ jobOutputs: [InputFile]) {
      for jobOutput in jobOutputs {
        switch jobOutput.type {
        case .object, .autolink:
          linkerInputs.append(jobOutput)

        case .swiftModule:
          moduleInputs.append(jobOutput)

        default:
          break
        }
      }
    }

    for input in inputFiles {
      switch input.type {
      case .swift, .sil, .sib:
        var jobOutputs: [InputFile] = []
        let job = compileJob(primaryInputs: [input], outputType: compilerOutputType, allOutputs: &jobOutputs)
        jobs.append(job)
        addJobOutputs(jobOutputs)

      case .object, .autolink:
        if linkerOutputType != nil {
          linkerInputs.append(input)
        } else {
          diagnosticEngine.emit(.error_unexpected_input_file(input.file))
        }

      case .swiftModule, .swiftDocumentation:
        if moduleOutputKind != nil && linkerOutputType == nil {
          // When generating a .swiftmodule as a top-level output (as opposed
          // to, for example, linking an image), treat .swiftmodule files as
          // inputs to a MergeModule action.
          moduleInputs.append(input)
        } else if linkerOutputType != nil {
          // Otherwise, if linking, pass .swiftmodule files as inputs to the
          // linker, so that their debug info is available.
          linkerInputs.append(input)
        } else {
          diagnosticEngine.emit(.error_unexpected_input_file(input.file))
        }

      default:
        diagnosticEngine.emit(.error_unexpected_input_file(input.file))
      }
    }

    // If we should link, do so.
    if linkerOutputType != nil && !linkerInputs.isEmpty {
      jobs.append(linkJob(inputs: linkerInputs))
    }

    // FIXME: Lots of follow-up actions for merging modules, etc.

    return jobs
  }

  /// Plan a build by producing a set of jobs to complete the build.
  public mutating func planBuild() -> [Job] {
    // Plan the build.
    switch compilerMode {
    case .immediate, .repl, .singleCompile:
      fatalError("Not yet supported")

    case .standardCompile:
      return planStandardCompile()
    }
  }
}

extension Diagnostic.Message {
  static func error_unexpected_input_file(_ file: VirtualPath) -> Diagnostic.Message {
    .error("unexpected input file: \(file.name)")
  }
}