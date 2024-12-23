use alua::ClassAnnotation;
use cdi_alert_engine::cac_data::*;

fn main() {
    println!("---@meta _");
    println!();
    println!("{}", Account::class_annotation());
    println!("{}", Patient::class_annotation());
    println!("{}", CACDocument::class_annotation());
    println!("{}", CodeReference::class_annotation());
    println!("{}", CodeReferenceWithDocument::class_annotation());
    println!("{}", Medication::class_annotation());
    println!("{}", DiscreteValue::class_annotation());
    println!("{}", AccountCustomWorkFlowEntry::class_annotation());
    println!("{}", CdiAlert::class_annotation());
    println!("{}", CdiAlertLink::class_annotation());
    println!("{}", AccountWorkingHistoryEntry::class_annotation());
    println!("{}", DiagnosisCode::class_annotation());
    println!("{}", ProcedureCode::class_annotation());
}
