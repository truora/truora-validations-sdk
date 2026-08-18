//
//  TruoraProcessResponse+Result.swift
//  TruoraValidationsSDK
//

import Foundation

// MARK: - Finalization

/// Projects a resolved ``TruoraProcessResponse`` snapshot into the aggregated
/// ``ProcessResult`` the runner emits, and mirrors the web runner's get-results /
/// risk-evaluation predicates so ``TruoraProcessManager`` can decide when a flow still
/// needs to wait on its risk evaluation.
extension TruoraProcessResponse {
    /// Whether the flow includes the synthetic `get_validations_result`
    /// block. Mirror of the web runner's `hasGetValidationsResults`, which
    /// inspects `identity_verification_names` (not the steps).
    ///
    /// When `true`, the process resolves an aggregate risk evaluation the SDK must
    /// wait on before finalizing.
    var hasGetResults: Bool {
        identityBlockTypes?.contains(TruoraBlockType.getValidationsResult.rawValue) ?? false
    }

    /// Whether the risk evaluation is still being computed. Mirror of the web
    /// runner's `isRiskEvaluationPending`: only the risk status is consulted, never
    /// the process status. A process with no risk evaluation is not pending.
    ///
    /// Not consumed by the runner itself — finalization waits on the *process*
    /// status (see ``TruoraProcessManager``), of which a pending risk is only a sub-case.
    /// This predicate exists for the results surface (PROC-6977), which distinguishes
    /// "results ready" from "risk still scoring"; until then it is exercised only by
    /// tests. Kept here rather than deferred so the model layer owns the wire
    /// semantics in one place.
    var isRiskEvaluationPending: Bool {
        riskEvaluation?.riskEvaluationStatus == .pending
    }

    /// Builds the terminal ``ProcessResult`` from this snapshot.
    ///
    /// - `status` defaults an absent process status to `.pending`.
    /// - `blocks` flattens the `verifications` map into ``TruoraBlock``
    ///   leaves — see ``resolvedBlocks()``.
    /// - `risk` carries the raw ``TruoraRiskEvaluationOutput`` through untouched.
    func toResult() -> ProcessResult {
        ProcessResult(
            processId: processId,
            status: status ?? .pending,
            failureStatus: failureStatus,
            blocks: resolvedBlocks(),
            risk: riskEvaluation
        )
    }

    /// Flattens the wire `verifications` map into ``TruoraBlock`` leaves.
    ///
    /// The backend keys the map with a composite `"<name>:<verification_id>"`
    /// (`models.NewVerificationKey`), so the key carries both the block name
    /// and its id; the value is the terminal status. Entries are sorted by key so
    /// the emission order (one ``ProcessEvent/blockCompleted(_:)`` each) is
    /// deterministic. Failure/decline/output detail is not present in the map, so
    /// those fields stay `nil` here.
    private func resolvedBlocks() -> [TruoraBlock] {
        guard let blocks else {
            return []
        }

        return blocks
            .sorted { $0.key < $1.key }
            .map { key, status in
                let parts = key.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                let name = parts.first.map(String.init) ?? key
                let blockId = parts.count > 1 ? String(parts[1]) : ""

                return TruoraBlock(
                    blockId: blockId,
                    type: TruoraBlockType(rawValue: name) ?? .unknown,
                    status: status
                )
            }
    }
}
