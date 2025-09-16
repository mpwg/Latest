//
//  UpdateTableView+Search.swift
//  Latest
//
//  Created by Max Langer on 27.12.18.
//  Copyright © 2018 Max Langer. All rights reserved.
//

import AppKit

/// Custom search field subclass that resigns first responder on ESC
class UpdateSearchField: NSSearchField {

	override func cancelOperation(_ sender: Any?) {
		self.window?.makeFirstResponder(nil)
	}
	
}

extension UpdateTableViewController {
	
	@IBAction func searchFieldTextDidChange(_ sender: NSSearchField) {
		let searchQuery = sender.stringValue.isEmpty ? nil : sender.stringValue
		self.viewModel?.setFilter(query: searchQuery)
	}
	
}
