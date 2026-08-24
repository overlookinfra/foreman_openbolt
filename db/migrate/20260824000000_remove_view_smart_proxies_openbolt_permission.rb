# frozen_string_literal: true

# Foreman never deletes Permission rows for permissions a plugin no longer
# registers, so upgrades would keep an orphaned view_smart_proxies_openbolt row.
# Drop it. The default roles keep proxy visibility through the core
# view_smart_proxies permission. If for some reason a custom role had the old
# permission applied and not view_smart_proxies, it would lose the smart proxy
# view permission and this can be easily fixed. But it's very unlikely anyone
# has a custom role configured like this.
class RemoveViewSmartProxiesOpenboltPermission < ActiveRecord::Migration[7.0]
  def up
    Permission.where(name: 'view_smart_proxies_openbolt').destroy_all
  end

  def down
    # The plugin no longer registers the permission so there's nothing to restore.
  end
end
