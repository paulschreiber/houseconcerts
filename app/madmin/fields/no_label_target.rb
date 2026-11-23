# For a field whose form partial has no single control for its label to name
# (plain text, or a group of radio buttons): the label gets no `for`.
module NoLabelTarget
  def label_target_id(_form)
    nil
  end
end
