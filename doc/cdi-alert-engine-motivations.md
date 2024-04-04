# CDI Alert Engine Project Overview/Motivation

## Introduction

This document gives a brief outline of the initial motivations and purpose for the CDI Alerts Engine project.
A lot of finer details are left out for clarity, as this is meant to be a high-level view.

## Overview of Current Relevant Architecture

In the current Fusion CAC 2 system, the workflow system processes an account when the account is queued for 
workflow due to account changes.

The primary purpose of workflow is to look at several properties on the account and to decide which workgroups
to assign an account to.  Workgroups determine assignment of the account to different groups of coders.  When 
coders log in to the system, the list(s) of accounts that they see are based on which accounts are assigned to 
their workgroups.

The CAC System has several workgroup "categories."  An account is assigned to one workgroup for each category.

A workgroup is made up of several "Criteria Groups."  The workgroup is considered to "match", and is assigned 
if at least one of these "Criteria Groups" match.

## CDI Alerts Related Features

The following features were added to workflow in the last year to support CDI alerts:

- A (python) scripting feature was added to workgroup assignment to run a script to see if an account should match
a workgroup. 
- Workgroups can calculate associated "evidence" for each of their "Criteria Groups" at assignment when they 
are added to the account through the scripting system.
- A UI section was added to the web application to display this evidence. 
- A feature was added to cause the assignment to be removed and not re-added if the evidence has already 
been marked as "validated" by the end-user

## The Problem

The CDI team has ~30 "alert" scripts in workflow that they want to note and attach evidence for various CDI
conditions.  When all 30 of these scripts are added and active, accounts are often taking a substantial amount of
time to go through workflow.  This is negatively impacting all account assignment, not just the new alert 
feature.

Currently, different scripts/alerts have had to be temporarily disabled to try to keep the system able to keep up.

## The Solution

The general idea is to leave the current system in place but to provide a way to slowly move the current "scripted"
CDI criteria groups to be processed asynchronously and by a faster application/scripting system.

### Script Engine Modifications

The script engine has been modified to do something special if it sees a script ending in ".lua"

- The workgroup/criteria is immediately considered not matching, and the assignment is not done.
- The account is queued in a new database collection called CdiAlertQueue
- The expectation is for application to process accounts in this queue by running various CDI alert scripts that
determine which alerts are relevent, collect CDI evidence, and to update the workgroup/criteria group assignment for a
configured CDI category to correspond to the first matching alert.

### CDI Alert Engine

At a high level, this engine:

- Polls the CdiAlertQueue collection for next entry (by oldest date first.)
- Removes the item from the collection.
- Runs all Cdi scripts and saves their evidence to the account.
- Assigns the WorkGroup/Criteria group for the (configurable) "CDI Alerts" category:
    - There is always only one workgroup (name configurable) Assign this if any alert passes, null it if not.
    - The assigned criteria group should be the one corresponding to the first passing script result

