/* Generated from Omarchy colors.toml for Material UI v9 GTK 3 consistency */

@define-color theme_bg_color {{ background }};
@define-color theme_fg_color {{ foreground }};
@define-color theme_base_color {{ lighter_background }};
@define-color theme_text_color {{ foreground }};
@define-color theme_selected_bg_color {{ accent }};
@define-color theme_selected_fg_color {{ background }};

@define-color insensitive_bg_color {{ dark_background }};
@define-color insensitive_fg_color {{ muted }};
@define-color insensitive_base_color {{ dark_background }};

@define-color theme_unfocused_bg_color {{ dark_background }};
@define-color theme_unfocused_fg_color {{ dark_foreground }};
@define-color theme_unfocused_base_color {{ background }};
@define-color theme_unfocused_text_color {{ dark_foreground }};
@define-color theme_unfocused_selected_bg_color {{ selection }};
@define-color theme_unfocused_selected_fg_color {{ foreground }};

@define-color borders {{ mix background foreground 14% }};
@define-color unfocused_borders {{ mix background foreground 10% }};

@define-color warning_color {{ orange }};
@define-color error_color {{ red }};
@define-color success_color {{ green }};

@define-color content_view_bg {{ lighter_background }};
@define-color text_view_bg {{ lighter_background }};

headerbar,
.titlebar {
  background-color: {{ dark_background }};
  color: {{ foreground }};
  border-color: @borders;
}

.sidebar,
placessidebar {
  background-color: {{ dark_background }};
  color: {{ foreground }};
}
