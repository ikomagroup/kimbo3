import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Ban } from 'lucide-react';

interface CancelDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: (reason: string) => void;
  title?: string;
  description?: string;
  entityType?: 'besoin' | 'da' | 'bl';
  isLoading?: boolean;
}

const entityLabels = {
  besoin: 'ce besoin',
  da: 'cette demande d\'achat',
  bl: 'ce bon de livraison',
};

export function CancelDialog({
  open,
  onOpenChange,
  onConfirm,
  title,
  description,
  entityType = 'da',
  isLoading = false,
}: CancelDialogProps) {
  const [reason, setReason] = useState('');

  const handleConfirm = () => {
    if (reason.trim().length >= 10) {
      onConfirm(reason.trim());
      setReason('');
    }
  };

  const handleClose = () => {
    setReason('');
    onOpenChange(false);
  };

  const entityLabel = entityLabels[entityType];

  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle className="flex items-center gap-2 text-destructive">
            <Ban className="h-5 w-5" />
            {title || `Annuler ${entityLabel}`}
          </AlertDialogTitle>
          <AlertDialogDescription>
            {description || `Cette action est irréversible. L'annulation de ${entityLabel} sera enregistrée dans le journal d'audit avec votre identité et la date.`}
          </AlertDialogDescription>
        </AlertDialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="cancel-reason">
              Motif d'annulation <span className="text-destructive">*</span>
            </Label>
            <Textarea
              id="cancel-reason"
              placeholder="Expliquez le motif de cette annulation (minimum 10 caractères)..."
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={3}
              className="resize-none"
            />
            {reason.length > 0 && reason.length < 10 && (
              <p className="text-xs text-destructive">
                Le motif doit contenir au moins 10 caractères ({reason.length}/10)
              </p>
            )}
          </div>
        </div>

        <AlertDialogFooter>
          <AlertDialogCancel onClick={handleClose} disabled={isLoading}>
            Annuler
          </AlertDialogCancel>
          <Button
            variant="destructive"
            onClick={handleConfirm}
            disabled={reason.trim().length < 10 || isLoading}
          >
            {isLoading ? 'Annulation...' : 'Confirmer l\'annulation'}
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
