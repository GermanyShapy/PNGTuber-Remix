@tool
extends EditorScript

func _run():
	if get_scene() == null:
		print_rich("[color=red]You must open a scene to run the translation checker.[/color]");
		return;
	for node in get_all_children(get_scene()):
		if node is Control:
			if !node.tooltip_text.is_empty() and !node.tooltip_text.begins_with("TR_"):
				untranslated_tooltip(node);
		if node is Label:
			var text = node.text;
			if node.get_parent() is BetterSlider:
				if !node.get_parent().label_text.contains("TR_"):
					untranslated_warning_label(node.get_parent());
			elif node is FormattedLocalizedLabel:
				if !text.contains("{") and !text.contains("TR_"):
					untranslated_warning_label(node);
			elif !text.begins_with("TR_"):
				untranslated_warning_label(node);
		elif node is OptionButton:
			for i in node.get_popup().item_count:
				if !node.get_popup().get_item_text(i).begins_with("TR_"):
					untranslated_warning_option_item(node, i);
		elif node is Button:
			if !node.text.is_empty() and !node.text.begins_with("TR_"):
				untranslated_warning_button(node);
	
	print("Done searching for untranslated keys.")


static func untranslated_tooltip(node: Node):
	print_rich("- [color=yellow]Control Node: %s's tooltip is untranslated[/color]\n" % node.get_path());


static func untranslated_warning_label(node: Node):
	print_rich("- [color=yellow]Label: %s may be untranslated[/color]\n" % node.get_path());


static func untranslated_warning_button(node: Node):
	print_rich("- [color=yellow]Button: %s may be untranslated[/color]\n" % node.get_path());


static func untranslated_warning_option_item(node: Node, item_id: int):
	print_rich("- [color=yellow]Lable: %s item %d may be untranslated[/color]\n" % [node.get_path(), item_id]);


func get_all_children(in_node, children_accumulater = []) -> Array:
	children_accumulater.push_back(in_node);
	for child in in_node.get_children():
		children_accumulater = get_all_children(child, children_accumulater);
	
	return children_accumulater;
