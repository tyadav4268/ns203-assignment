"""
ESP 4AFC Analysis for One Sender-Receiver Pair

Run:
    python esp_sdt_analysis.py

Select:
    1. Sender CSV
    2. Receiver CSV

The pair ID is read automatically from the CSV files.
Run the script again to analyse another pair.

Requirements:
    pip install pandas numpy scipy matplotlib
"""

from pathlib import Path
import sys
import tkinter as tk
from tkinter import filedialog

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from scipy.integrate import quad
from scipy.optimize import brentq
from scipy.stats import binomtest, norm


# --------------------------- EXPERIMENT SETTINGS ---------------------------

N_ALTERNATIVES = 4
CHANCE_LEVEL = 1.0 / N_ALTERNATIVES
ALPHA = 0.05
CONFIDENCE_LEVEL = 0.95

TARGET_COLUMN_CANDIDATES = [
    "target",
    "target_image",
    "image",
    "target_label"
]

RESPONSE_COLUMN_CANDIDATES = [
    "response",
    "choice",
    "selected_image",
    "response_image"
]

NO_RESPONSE_VALUES = {
    "",
    "NO_RESPONSE",
    "NO RESPONSE",
    "NONE",
    "NAN",
    "NULL"
}


# ------------------------------ FILE SELECTION ------------------------------

def select_csv(title):

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)

    selected_file = filedialog.askopenfilename(
        title=title,
        filetypes=[
            ("CSV files", "*.csv"),
            ("All files", "*.*")
        ]
    )

    root.destroy()

    if not selected_file:
        raise RuntimeError(
            f"No file selected for: {title}\nAnalysis cancelled."
        )

    path = Path(selected_file)

    if not path.exists():
        raise FileNotFoundError(
            f"Selected file does not exist:\n{path}"
        )

    if path.suffix.lower() != ".csv":
        raise ValueError(
            f"Selected file is not a CSV file:\n{path}"
        )

    return path


def load_csv(path, file_description):

    try:
        data = pd.read_csv(path)

    except Exception as error:
        raise RuntimeError(
            f"Could not read the {file_description} CSV:\n"
            f"{path}\n"
            f"Original error: {error}"
        )

    if data.empty:
        raise ValueError(
            f"The {file_description} CSV contains no data:\n{path}"
        )

    data.columns = data.columns.astype(str).str.strip()

    if data.columns.duplicated().any():

        duplicate_columns = data.columns[
            data.columns.duplicated()
        ].tolist()

        raise ValueError(
            f"Duplicate column names in {file_description} CSV: "
            f"{duplicate_columns}"
        )

    return data


# ------------------------------- VALIDATION --------------------------------

def find_column(data, candidates, description, file_path):

    column_lookup = {
        column.strip().lower(): column
        for column in data.columns
    }

    for candidate in candidates:

        if candidate.lower() in column_lookup:
            return column_lookup[candidate.lower()]

    raise ValueError(
        f"Could not find the {description} column in:\n"
        f"{file_path}\n\n"
        f"Expected one of: {candidates}\n"
        f"Columns found: {list(data.columns)}"
    )


def require_columns(data, required_columns, file_description, file_path):

    missing_columns = [
        column
        for column in required_columns
        if column not in data.columns
    ]

    if missing_columns:

        raise ValueError(
            f"Missing required column(s) in {file_description} file:\n"
            f"{file_path}\n\n"
            f"Missing: {missing_columns}\n"
            f"Available: {list(data.columns)}"
        )


def normalise_text(series):

    return series.astype("string").str.strip()


def validate_pair_files(sender, receiver, sender_path, receiver_path):

    require_columns(
        sender,
        ["pair_id", "block", "trial"],
        "sender",
        sender_path
    )

    require_columns(
        receiver,
        ["pair_id", "block", "trial"],
        "receiver",
        receiver_path
    )

    sender_target_column = find_column(
        sender,
        TARGET_COLUMN_CANDIDATES,
        "target image",
        sender_path
    )

    receiver_response_column = find_column(
        receiver,
        RESPONSE_COLUMN_CANDIDATES,
        "receiver response",
        receiver_path
    )

    sender = sender.copy()
    receiver = receiver.copy()

    sender["pair_id"] = normalise_text(sender["pair_id"])
    receiver["pair_id"] = normalise_text(receiver["pair_id"])

    sender["block"] = normalise_text(sender["block"])
    receiver["block"] = normalise_text(receiver["block"])

    sender["trial"] = normalise_text(sender["trial"])
    receiver["trial"] = normalise_text(receiver["trial"])

    sender["target"] = normalise_text(
        sender[sender_target_column]
    )

    receiver["response"] = normalise_text(
        receiver[receiver_response_column]
    )

    for description, data, path in [
        ("sender", sender, sender_path),
        ("receiver", receiver, receiver_path)
    ]:

        key_columns = ["pair_id", "block", "trial"]

        if data[key_columns].isna().any().any():

            raise ValueError(
                f"Missing pair_id, block, or trial value in "
                f"{description} file:\n{path}"
            )

        if (data[key_columns] == "").any().any():

            raise ValueError(
                f"Blank pair_id, block, or trial value in "
                f"{description} file:\n{path}"
            )

        if data.duplicated(key_columns).any():

            duplicate_rows = data.loc[
                data.duplicated(key_columns, keep=False),
                key_columns
            ]

            raise ValueError(
                f"Duplicate trial identifiers found in "
                f"{description} file:\n"
                f"{path}\n\n"
                f"{duplicate_rows.to_string(index=False)}"
            )

    sender_pair_ids = sender["pair_id"].dropna().unique().tolist()
    receiver_pair_ids = receiver["pair_id"].dropna().unique().tolist()

    if len(sender_pair_ids) != 1:

        raise ValueError(
            f"Sender file must contain exactly one pair ID.\n"
            f"Found: {sender_pair_ids}"
        )

    if len(receiver_pair_ids) != 1:

        raise ValueError(
            f"Receiver file must contain exactly one pair ID.\n"
            f"Found: {receiver_pair_ids}"
        )

    sender_pair_id = sender_pair_ids[0]
    receiver_pair_id = receiver_pair_ids[0]

    if sender_pair_id != receiver_pair_id:

        raise ValueError(
            "PAIR ID MISMATCH.\n"
            f"Sender pair ID: {sender_pair_id}\n"
            f"Receiver pair ID: {receiver_pair_id}\n\n"
            "Please select the sender and receiver files belonging "
            "to the same pair. Analysis stopped."
        )

    if sender["target"].isna().any() or (sender["target"] == "").any():

        raise ValueError(
            "Sender file contains missing target labels. "
            "Analysis stopped."
        )

    merged = sender[
        ["pair_id", "block", "trial", "target"]
    ].merge(
        receiver[
            ["pair_id", "block", "trial", "response"]
        ],
        on=["pair_id", "block", "trial"],
        how="outer",
        indicator=True,
        validate="one_to_one"
    )

    unmatched_sender = merged.loc[
        merged["_merge"] == "left_only",
        ["pair_id", "block", "trial"]
    ]

    unmatched_receiver = merged.loc[
        merged["_merge"] == "right_only",
        ["pair_id", "block", "trial"]
    ]

    if not unmatched_sender.empty or not unmatched_receiver.empty:

        details = []

        if not unmatched_sender.empty:

            details.append(
                "Trials present in sender file but missing "
                "from receiver file:\n"
                + unmatched_sender.to_string(index=False)
            )

        if not unmatched_receiver.empty:

            details.append(
                "Trials present in receiver file but missing "
                "from sender file:\n"
                + unmatched_receiver.to_string(index=False)
            )

        raise ValueError(
            "SENDER/RECEIVER TRIAL MISMATCH.\n\n"
            + "\n\n".join(details)
            + "\n\nAnalysis stopped. No trials were silently discarded."
        )

    merged = merged.drop(columns=["_merge"])

    target_labels = sorted(
        merged["target"].dropna().astype(str).str.casefold().unique()
    )

    if len(target_labels) != N_ALTERNATIVES:

        raise ValueError(
            f"Expected exactly {N_ALTERNATIVES} target categories "
            f"for this 4AFC task, but found {len(target_labels)}:\n"
            f"{target_labels}\n\n"
            "Check the sender CSV and target labels."
        )

    valid_response_lookup = {
        label.casefold(): label
        for label in merged["target"].dropna().unique()
    }

    response_text = (
        merged["response"]
        .fillna("")
        .astype(str)
        .str.strip()
    )

    response_upper = response_text.str.upper()

    merged["no_response"] = response_upper.isin(
        NO_RESPONSE_VALUES
    )

    invalid_responses = sorted({
        value
        for value in response_text[~merged["no_response"]]
        if value.casefold() not in valid_response_lookup
    })

    if invalid_responses:

        raise ValueError(
            "Receiver file contains response labels that do not "
            "match any of the four target categories:\n"
            f"{invalid_responses}\n\n"
            f"Valid categories: "
            f"{sorted(valid_response_lookup.values())}\n"
            "Check spelling/capitalisation in the CSV files."
        )

    merged["correct"] = (
        (~merged["no_response"])
        & (
            merged["target"].astype(str).str.casefold()
            == response_text.str.casefold()
        )
    )

    merged["target"] = merged["target"].astype(str)

    merged["response"] = response_text.replace(
        "",
        "NO_RESPONSE"
    )

    return sender_pair_id, merged

# -------------------------- SIGNAL DETECTION THEORY -------------------------

def pc_from_dprime(dprime, number_of_alternatives):

    """
    Independent-observations Gaussian m-AFC model:

    Pc = integral phi(x - d') * Phi(x)^(m - 1) dx

    Signal evidence: N(d', 1)
    Noise evidence: N(0, 1)

    Observer chooses the alternative with the largest evidence.
    """

    def integrand(x):

        return (
            norm.pdf(x - dprime)
            * norm.cdf(x) ** (number_of_alternatives - 1)
        )

    probability_correct, _ = quad(
        integrand,
        -10,
        10,
        epsabs=1e-10,
        epsrel=1e-10,
        limit=300
    )

    return probability_correct


def estimate_4afc_dprime(proportion_correct):

    if not 0 < proportion_correct < 1:
        return np.nan

    def objective(dprime):

        return (
            pc_from_dprime(dprime, N_ALTERNATIVES)
            - proportion_correct
        )

    return brentq(
        objective,
        -10,
        10,
        xtol=1e-10
    )


# ------------------------------- ANALYSIS -----------------------------------

def analyse_pair(pair_id, merged):

    number_of_trials = len(merged)

    number_correct = int(
        merged["correct"].sum()
    )

    number_no_response = int(
        merged["no_response"].sum()
    )

    number_responded = (
        number_of_trials - number_no_response
    )

    accuracy = (
        number_correct / number_of_trials
    )

    primary_test = binomtest(
        number_correct,
        number_of_trials,
        p=CHANCE_LEVEL,
        alternative="greater"
    )

    confidence_interval = binomtest(
        number_correct,
        number_of_trials
    ).proportion_ci(
        confidence_level=CONFIDENCE_LEVEL,
        method="exact"
    )

    if number_responded > 0:

        responded_accuracy = (
            number_correct / number_responded
        )

        responded_test = binomtest(
            number_correct,
            number_responded,
            p=CHANCE_LEVEL,
            alternative="greater"
        )

        dprime = estimate_4afc_dprime(
            responded_accuracy
        )

    else:

        responded_accuracy = np.nan
        responded_test = None
        dprime = np.nan

    block_summary = (
        merged.groupby("block", sort=True)
        .agg(
            trials=("correct", "size"),
            correct=("correct", "sum"),
            no_response=("no_response", "sum")
        )
        .reset_index()
    )

    block_summary["accuracy"] = (
        block_summary["correct"]
        / block_summary["trials"]
    )

    result = {
        "pair_id": pair_id,
        "total_trials": number_of_trials,
        "correct_trials": number_correct,
        "no_response_trials": number_no_response,
        "accuracy": accuracy,
        "chance_level": CHANCE_LEVEL,
        "difference_from_chance_percentage_points": (
            accuracy - CHANCE_LEVEL
        ) * 100,
        "exact_binomial_p_one_sided": primary_test.pvalue,
        "confidence_interval_95_low": confidence_interval.low,
        "confidence_interval_95_high": confidence_interval.high,
        "responded_trials": number_responded,
        "responded_only_accuracy": responded_accuracy,
        "responded_only_p_one_sided": (
            responded_test.pvalue
            if responded_test is not None
            else np.nan
        ),
        "4afc_dprime_responded_trials": dprime,
        "significant_at_0.05": (
            primary_test.pvalue < ALPHA
        )
    }

    return result, block_summary


# ------------------------------- PLOTS -------------------------------------

def make_plots(pair_id, block_summary, accuracy, output_directory):

    figure, axis = plt.subplots(
        figsize=(6.5, 4.8)
    )

    axis.bar(
        [f"Pair {pair_id}"],
        [accuracy * 100]
    )

    axis.axhline(
        CHANCE_LEVEL * 100,
        linestyle="--",
        linewidth=1.5,
        label="Chance level (25%)"
    )

    axis.set_ylabel("Accuracy (%)")

    axis.set_ylim(
        0,
        max(45, accuracy * 100 + 8)
    )

    axis.set_title("Receiver accuracy")
    axis.legend()
    figure.tight_layout()

    figure.savefig(
        output_directory / f"{pair_id}_accuracy.png",
        dpi=300
    )

    plt.close(figure)

    figure, axis = plt.subplots(
        figsize=(6.5, 4.8)
    )

    axis.plot(
        block_summary["block"].astype(str),
        block_summary["accuracy"] * 100,
        marker="o",
        linewidth=2
    )

    axis.axhline(
        CHANCE_LEVEL * 100,
        linestyle="--",
        linewidth=1.5,
        label="Chance level (25%)"
    )

    axis.set_xlabel("Block")
    axis.set_ylabel("Accuracy (%)")
    axis.set_ylim(0, 100)
    axis.set_title("Receiver accuracy across blocks")
    axis.legend()
    figure.tight_layout()

    figure.savefig(
        output_directory / f"{pair_id}_block_accuracy.png",
        dpi=300
    )

    plt.close(figure)


# ----------------------------- TEXT REPORT ---------------------------------

def save_text_report(result, block_summary, output_directory):

    pair_id = result["pair_id"]

    lines = [
        "ESP FOUR-ALTERNATIVE FORCED-CHOICE ANALYSIS",
        "=" * 60,
        f"Pair ID: {pair_id}",
        "",
        "PRIMARY ANALYSIS",
        f"Correct responses: {result['correct_trials']} / "
        f"{result['total_trials']}",
        f"No-response trials: {result['no_response_trials']}",
        f"Accuracy: {result['accuracy'] * 100:.2f}%",
        f"Chance level: {result['chance_level'] * 100:.2f}%",
        "Test: one-sided exact binomial test (H1: accuracy > 0.25)",
        f"p-value: {result['exact_binomial_p_one_sided']:.6f}",
        (
            "95% exact confidence interval: "
            f"[{result['confidence_interval_95_low'] * 100:.2f}%, "
            f"{result['confidence_interval_95_high'] * 100:.2f}%]"
        ),
        f"Significant at alpha = {ALPHA:.2f}: "
        f"{result['significant_at_0.05']}",
        "",
        "SECONDARY ANALYSIS (RESPONDED TRIALS ONLY)",
        f"Number of responses: {result['responded_trials']}",
        f"Responded-only accuracy: "
        f"{result['responded_only_accuracy'] * 100:.2f}%",
        f"Responded-only one-sided p-value: "
        f"{result['responded_only_p_one_sided']:.6f}",
        f"Gaussian 4AFC d-prime estimate: "
        f"{result['4afc_dprime_responded_trials']:.4f}",
        "",
        "BLOCK-WISE RESULTS",
        block_summary.to_string(index=False),
        "",
        "INTERPRETATION NOTES",
        "- No-response trials are counted as incorrect in the primary test.",
        "- Responded-only results are a secondary sensitivity analysis.",
        "- The 4AFC d-prime is a model-based descriptive estimate.",
        "- The d-prime estimate is not a standalone significance test.",
        "- The Gaussian m-AFC model assumes independent evidence samples.",
        "- Semantic image categories may not fully satisfy those assumptions.",
        "- A non-significant result is not proof that ESP is impossible.",
        "- A significant result would require replication and exclusion of cues."
    ]

    report_path = (
        output_directory / f"{pair_id}_analysis_report.txt"
    )

    report_path.write_text(
        "\n".join(lines),
        encoding="utf-8"
    )


# -------------------------- VALIDATION SUMMARY ------------------------------

def print_validation_summary(pair_id, merged):

    print("\n" + "=" * 68)
    print("INPUT FILE VALIDATION")
    print("=" * 68)

    print(f"Pair ID: {pair_id}")
    print(f"Matched trials: {len(merged)}")
    print(f"Blocks: {merged['block'].nunique()}")

    print("\nTarget counts:")

    print(
        merged["target"]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print("\nResponse counts:")

    print(
        merged["response"]
        .value_counts()
        .sort_index()
        .to_string()
    )

    print(
        "\nValidation successful. All sender and receiver "
        "trials matched."
    )


# --------------------------------- MAIN -------------------------------------

def main():

    print("=" * 68)
    print("ESP 4AFC ANALYSIS")
    print("=" * 68)

    print(
        "\nSelect the sender and receiver CSV files for ONE pair."
    )

    print(
        "Run this program again to analyse another pair."
    )

    sender_path = select_csv(
        "Select the SENDER CSV file"
    )

    receiver_path = select_csv(
        "Select the RECEIVER CSV file"
    )

    sender = load_csv(
        sender_path,
        "sender"
    )

    receiver = load_csv(
        receiver_path,
        "receiver"
    )

    pair_id, merged = validate_pair_files(
        sender,
        receiver,
        sender_path,
        receiver_path
    )

    print_validation_summary(
        pair_id,
        merged
    )

    output_directory = (
        Path.cwd()
        / "ESP_Analysis_Results"
        / str(pair_id)
    )

    output_directory.mkdir(
        parents=True,
        exist_ok=True
    )

    result, block_summary = analyse_pair(
        pair_id,
        merged
    )

    merged.to_csv(
        output_directory / f"{pair_id}_merged_trial_data.csv",
        index=False
    )

    block_summary.to_csv(
        output_directory / f"{pair_id}_block_summary.csv",
        index=False
    )

    pd.DataFrame([result]).to_csv(
        output_directory / f"{pair_id}_summary.csv",
        index=False
    )

    make_plots(
        pair_id,
        block_summary,
        result["accuracy"],
        output_directory
    )

    save_text_report(
        result,
        block_summary,
        output_directory
    )

    print("\n" + "=" * 68)
    print("ANALYSIS RESULTS")
    print("=" * 68)

    print(
        f"Accuracy: {result['correct_trials']}/"
        f"{result['total_trials']} "
        f"({result['accuracy'] * 100:.2f}%)"
    )

    print(
        f"Chance level: "
        f"{result['chance_level'] * 100:.2f}%"
    )

    print(
        "One-sided exact binomial p-value: "
        f"{result['exact_binomial_p_one_sided']:.6f}"
    )

    print(
        "95% exact confidence interval: "
        f"[{result['confidence_interval_95_low'] * 100:.2f}%, "
        f"{result['confidence_interval_95_high'] * 100:.2f}%]"
    )

    print(
        "4AFC d-prime (responded trials): "
        f"{result['4afc_dprime_responded_trials']:.4f}"
    )

    if result["significant_at_0.05"]:

        print(
            "\nResult: Accuracy is significantly above chance "
            f"at alpha = {ALPHA:.2f}."
        )

    else:

        print(
            "\nResult: Accuracy is NOT significantly above chance "
            f"at alpha = {ALPHA:.2f}."
        )

    print("\nBlock-wise accuracy:")

    print(
        block_summary[
            ["block", "correct", "trials", "no_response", "accuracy"]
        ].to_string(index=False)
    )

    print("\nAll outputs saved to:")

    print(output_directory.resolve())

    print("\nFiles created:")

    print(f"- {pair_id}_summary.csv")
    print(f"- {pair_id}_block_summary.csv")
    print(f"- {pair_id}_merged_trial_data.csv")
    print(f"- {pair_id}_accuracy.png")
    print(f"- {pair_id}_block_accuracy.png")
    print(f"- {pair_id}_analysis_report.txt")


if __name__ == "__main__":

    try:
        main()

    except Exception as error:

        print("\n" + "!" * 68)
        print("ANALYSIS STOPPED")
        print("!" * 68)

        print(error)

        sys.exit(1)