require 'rails_helper'

describe ConstraintsController do
  describe "on GET show" do
    let(:constraint) { FactoryBot.create :constraint, key: 'total_primary_energy' }

    let(:response) { get(:show, params: { id: constraint.id }) }

    it { expect(response).to be_successful }
    it { expect(response).to render_template(:show) }
  end
end
