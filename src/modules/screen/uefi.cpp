/*
 * uefi.cpp
 *
 *  Created on: Aug 12, 2016
 *      Author: chris13524
 */

#include <string.h>
#include <boot/uefi.h>
#include <log.h>

static UINTN foreground;
static UINTN background;

void uefi_terminal_clear() {
	EFI_STATUS status = uefi_call_wrapper(
			(void* ) systemTable->ConOut->ClearScreen, 1, systemTable->ConOut);
	if (status != EFI_SUCCESS) {
		debug(L"EFI_STATUS", status);
		crash(L"failed to clear terminal");
	}
}

void uefi_terminal_writeString(String message) {
	EFI_STATUS status = uefi_call_wrapper(
			(void* ) systemTable->ConOut->OutputString, 2, systemTable->ConOut,
			message);
	if (status != EFI_SUCCESS) {
		debug(L"EFI_STATUS", status);
		crash(L"failed to write string");
	}
}

static void updateColor() {
	EFI_STATUS status = uefi_call_wrapper(
			(void* ) systemTable->ConOut->SetAttribute, 2, systemTable->ConOut,
			EFI_TEXT_ATTR(foreground,background));
	if (status != EFI_SUCCESS) {
		debug(L"EFI_STATUS", status);
		crash(L"failed to set terminal color");
	}
}

void uefi_terminal_setForegroundColor(UINTN color) {
	foreground = color;
	updateColor();
}

void uefi_terminal_setBackgroundColor(UINTN color) {
	background = color;
	updateColor();
}